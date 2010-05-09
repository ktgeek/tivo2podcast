# Copyright 2010 Keith T. Garner. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#
require 'sqlite3'
require 'TiVo'
require 'set'

module Tivo2Podcast
  class Config
    attr_accessor :verbose, :opt_config_names, :tivodecode
    attr_accessor :handbrake, :cleanup, :atomicparsley
    attr_writer :tivo_addr, :mak

    def initialize
      @tivo_addr = nil
      @mak = nil
      @verbose = false
      @opt_config_names = nil
      @tivodecode = 'tivodecode'
      @handbrake = 'HandBrakeCLI'
      @cleanup = false
      @atomicparsley = 'AtomicParsley'
    end

    def tivo_factory
      return TiVo::TiVo.new(tivo_addr, mak)
    end

    def tivo_addr
      # If the user didn't pass in a address or hostname via the command line,
      # try to locate it via dnssd.
      if @tivo_addr.nil?
        puts "Attemping to locate tivo..." if @verbose
        tmp = TiVo.locate_via_dnssd
        if tmp.nil?
          puts "TiVo not found!" if @verbose
          # Should be changed to an exception to be throw
          printf($stderr, "TiVo hostname or IP required to run the script\n")
          exit(1)
        else
          puts "TiVo found at #{tmp}" if @verbose
          @tivo_addr = tmp
        end
      end

      result = @tivo_addr
      # If the tivo_addr is NOT a dotted quad, do a DNS lookup for the
      # IP. The TiVo wants us to pass the IP address for whatever reason.
      # I should use bounjour/ZeroConf to find the local tivo
      if /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(result).nil?
        result = IPSocket.getaddress(@tivo_addr)
      end
      
      return result
    end

    def mak
      if @mak.nil?
        # Load the mak if we have a mak file
        mak_file = ENV['HOME'] + '/.tivodecode_mak'
        @mak = File.read(mak_file).strip if File.exist?(mak_file)
      end
      return @mak
    end
  end
    
  class MainEngine
    def initialize(config)
      @config = config
      @db = Tivo2Podcast::Database.new((ENV['TIVO2PODCASTDIR'].nil? ?
                                        ENV['HOME'] :
                                        ENV['TIVO2PODCASTDIR']) +
                                       File::SEPARATOR + '.tivo2podcast.db')
    end

    def download_show(show, name)
      tivo = @config.tivo_factory

      # downlaod the file
      IO.popen("#{@config.tivodecode} -n -o \"#{name}\" -", 'wb') do |td|
        pbar = @config.verbose ? Console::ProgressBar.new(name, show.size) : nil
        tivo.download_show(show) do |tc|
          td << tc
          pbar.inc(tc.length) unless pbar.nil?
        end
        pbar.finish unless pbar.nil?
        puts
      end
    end

    def create_rss(config)
      rss = Tivo2Podcast::RssGenerator.new(config, @db)
      File.open(config['rss_filename'], 'w') { |f| f << rss.generate() }
    end

    def normal_processing
      configs = @db.get_configs(@config.opt_config_names)

      tivo = @config.tivo_factory

      configs.each do |config|
        shows = tivo.get_shows_by_name(config['show_name'])

        # Only work on the X latest shows.  That way if there are 10
        # on the tivo, but we only want to keep 4, we don't encode 6
        # of them just to throw them out later in the cleanup phase.
        if shows.size > config['ep_to_keep']
          shows = shows.reverse[0, config['ep_to_keep']].reverse
        end

        # So starts the giant loop that processes the shows...
        shows.each do |s|
          # Beef this up to capture the show title as well
          basename = s.title + '-' + s.time_captured.strftime("%Y%m%d")
          basename = basename + '-' + s.episode_title unless s.episode_title.nil?
          basename = basename + '-' + s.episode_number unless s.episode_number.nil?
          basename.sub!(/:/, '_')

          download = basename + ".mpg"
          transcode = basename + ".m4v"

          # We'll need the later condition until everything has a program_id
          # (this is only for my own migration.)
          unless (@db.got_show?(config, s) || File.exist?(download) ||
                  File.exist?(transcode))
            download_show(s, download)
            
            transcoder = Tivo2Podcast::Transcoder.new(@config, config, s)
            transcoder.transcode_show(download, transcode)

            File.delete(download)

            @db.add_show(s, config, transcode)
          else
            puts "Skipping #{basename} because it seems to exist" if @config.verbose
          end
        end

        # cleanup phase goes here
        deletes = @db.old_show_cleanup(config)
        deletes.each { |f| File.delete(f) }

        create_rss(config)
      end
    end

    def file_cleanup
      # Get shows by id,configid,filename
      configids = Set.new
      deleteids = Array.new
      @db.get_filenames do |row|
        unless File.exists?(row['filename'])
          puts "#{row['filename']} missing, removing from database."
          configids.add(row['configid'])
          deleteids << row['id']
        end
      end

      @db.delete_shows(deleteids) unless deleteids.empty?

      unless configids.empty?
        configs = @db.get_configs_by_ids(configids.to_a)
        configs.each { |c| create_rss(c) }
      end
    end
  end

  # Database access facade for the state information between script runs
  class Database
    # filename - The name of the sqlite file.
    def initialize(filename)
      db_needs_init = !File.exist?(filename)

      @db = SQLite3::Database.new(filename)
      @db.results_as_hash = true
      @db.type_translation = true

      init_database if db_needs_init
    end

    # Creates the database tables that this class acts as a facade for
    def init_database()
      @db.execute_batch(<<SQL
create table configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_name TEXT NOT NULL UNIQUE,
    show_name TEXT NOT NULL,
    rss_filename TEXT NOT NULL,
    rss_link TEXT NOT NULL,
    rss_baseurl TEXT NOT NULL,
    rss_ownername TEXT NOT NULL,
    rss_owneremail TEXT NOT NULL,
    ep_to_keep INTEGER NOT NULL DEFAULT 5,
    encode_crop TEXT,
    encode_audio_bitrate INTEGER,
    encode_video_bitrate INTEGER,
    encode_decomb INTEGER,
    max_width INTEGER,
    max_height INTEGER
);
create index configs_config_name_index on configs(config_name);
create table shows (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    configid TEXT NOT NULL,
    s_name TEXT,
    s_ep_title TEXT,
    s_ep_number TEXT,
    s_ep_description TEXT,
    s_ep_length INTEGER,
    s_ep_timecap INTEGER,
    s_ep_programid TEXT NOT NULL,
    filename TEXT UNIQUE,
    FOREIGN KEY(configid) REFERENCES configs(id)
);
create index shows_programid_index on shows(s_ep_programid);
create index shows_configid_index on shows(configid);
SQL
                        )
    end

    # Gets the configs from the config table, by default it will get all unless
    # an array of names is passed in.
    def get_configs(names=nil)
      result = Array.new
      if names.nil? || names.empty?
        @db.query("select * from configs") { |rs| rs.each { |r| result << r } }
      else
        qms = Array.new(names.size, '?').join(',')
        @db.query("select * from configs where config_name in (#{qms})",
                  names) do |rs|
          rs.each { |r| result << r }
        end
      end
      return result
    end

    # Gets the configs from the config table based on the Array of
    # config ids passed in.
    def get_configs_by_ids(configs)
      result = Array.new
      qms = Array.new(configs.size, '?').join(',')
      @db.query("select * from configs where id in (#{qms})", configs) do |rs|
        rs.each { |r| result << r }
      end
      return result
    end

    # Select all the shows for a given config id
    def shows_by_configid(id, &block)
      @db.query("select * from shows where configid=?", id) do |rows|
        rows.each { |row| yield row }
      end
    end

    # Returns the filenames for everything in the show table and their
    # associated ids and configids...
    def get_filenames(&block)
      @db.query("select id,configid,filename from shows") do |rows|
        rows.each { |row| yield row }
      end
    end

    # Add a show to the database for a given config and video stored
    # in the given filename
    def add_show(show, config, filename)
      ps = @db.prepare('insert into shows(configid, s_name, s_ep_title, s_ep_number, s_ep_description, s_ep_length, s_ep_timecap, s_ep_programid, filename) values (?, ?, ?, ?, ?, ?, ?, ?, ?);')
      ps.execute(config['id'], show.title, show.episode_title(true),
             show.episode_number, show.description, show.duration,
             show.time_captured.to_i, show.program_id, filename)
      ps.close()
    end

    # Cleans up shows that go over the keep threshold specified in the config
    def old_show_cleanup(config)
      filenames = Array.new\
      @db.execute('create temp table cleanup_temp as select id,filename from shows where configid=? order by s_ep_timecap desc;', config['id'])
      @db.query('select id,filename from cleanup_temp where rowid>?',
                config['ep_to_keep']) do |results|
        results.each do |r|
          filenames << r['filename']
          @db.execute('delete from shows where id=?;', r['id'])
        end
      end
      # Yes, its only in memory, but we may be called many times in here.
      @db.execute('drop table cleanup_temp;')
      return filenames
    end

    def delete_shows(shows)
      qms = Array.new(shows.size, '?').join(',')
      @db.execute("delete from shows where id in (#{qms})", shows)
    end

    # Reports if a show is in the database by looking to see if
    # program_id is in the database.
    def got_show?(config, show)
      got_one = false
      # There is probably a better way to test for existance, but I'll
      # ask for help later
      @db.query('select 1 from shows where configid=? and s_ep_programid=?',
                config['id'], show.program_id) do |results|
        got_one = true
      end
      return got_one
    end
      
  end

  # This class encapsulates both calling out to handbrake to doing the
  # transcoding from source mpg to iPhone friendly m4v, as well as
  # calling out to AtomicParsley to add the video metadata to the file.
  class Transcoder
    attr_writer :crop, :audio_bitrate, :video_bitrate, :max_width, :max_height

    # config is assumed to be a HashTable with the configuration information
    # as sepecified in Database.init_database (I should probably turn
    # configuration into an object.)
    #
    # show is assumed to be an instance of TiVo::TiVoVideo which holds
    # the metadata of the show to be transcoded.
    def initialize(config, show_config, show)
      @config = config
      @show_config = show_config
      @show = show
      @crop = nil
      @audio_bitrate = nil
      @video_bitrate = nil
      @max_width = nil
      @max_height = nil
    end

    def crop
      @crop.nil? ? @show_config['encode_crop'] : @crop
    end

    def audio_bitrate
      ab = @audio_bitrate.nil? ? @show_config['encode_audio_bitrate'] : @audio_bitrate
      ab = 48 if ab.nil?
      return ab
    end

    def video_bitrate
      vb = @video_bitrate.nil? ? @show_config['encode_video_bitrate'] : @video_bitrate
      vb = 768 if vb.nil?
      return vb
    end

    def max_width
      mw = @max_width.nil? ? @show_config['max_width'] : @max_width
      mw = 480 if mw.nil?
      return vb
    end

    def max_height
      @max_height.nil? ? @show_config['max_height'] : @max_height
    end

    def decomb?
      decomb = @decomb.nil? ? @show_config['encode_decomb'] : @decomb
      (decomb.nil? || decomb == 0) ? false : true
    end

    # This transcodes and properly tags the show.  infile is the
    # filename of the sourcefile, outfile is the filename to transcode
    # to
    def transcode_show(infile, outfile)
      command = "#{@config.handbrake} -v0 -e x264 -b#{video_bitrate.to_s} -2 -T"
      command += ' -5 default' if decomb?
      command += " --crop #{crop}" unless crop.nil?
      command += " -a 1 -E faac -B#{audio_bitrate.to_s} -6 stereo -R 48 " +
        "-D 0.0 -f mp4 -X #{max_width}"
      command += "-Y #{max_height}" unless max_height.nil?
      command += '-x cabac=0:ref=2:me=umh:bframes=0:subme=6:8x8dct=0:trellis=0 '
              + "-i \"#{infile}\" -o \"#{outfile}\""
      command += " >/dev/null 2>&1" unless @config.verbose
                                  
      returncode = system(command)
      if !returncode
        puts "something isn't working right, bailing"
        puts "Command that failed: " + command
        # TODO: Change this to an exception
        exit(1)
      end

      #   --title (str)    Set the title tag: "moov.udta.meta.ilst.©nam.data"
      #   --TVNetwork (str)    Sets the TV Network name on the "tvnn" atom
      #   --TVShowName (str)    Sets the TV Show name on the "tvsh" atom
      #   --TVEpisode (str)    Sets the TV Episode on "tven":"209", but its a string: "209 Part 1"
      #   --TVSeasonNum (num)    Sets the TV Season number on the "tvsn" atom
      #   --TVEpisodeNum (num)    Sets the TV Episode number on the "tves" atom
      #   --description (str)    Sets the description on the "desc" atom
      showtitle = @show.title + ': ' + @show.episode_title(true)
      showtitle = showtitle + ' (' + @show.episode_number +
        ')' unless @show.episode_number.nil?

      command = "#{@config.atomicparsley} \"#{outfile}\" -W " +
        "--title \"#{showtitle}\" --TVShowName \"#{@show.title}\" " +
        "--TVEpisode \"#{@show.episode_title(true)}\""
      command += " --TVEpisodeNum #{@show.episode_number}" unless @show.episode_number.nil?
      command += " --TVNetwork \"#{@show.station}\"" unless @show.station.nil?
      unless @show.description.nil?
        desc = @show.description.gsub(/"/, '\"')
        command += " --description \"#{@desc}\""
      end
      command += ' >/dev/null 2>&1' unless @config.verbose
      returncode = system(command)
      if !returncode
        puts "something isn't working right, bailing"
        puts "Command that failed: " + command
        # TODO: change this to an exception
        exit(1)
      end                                
    end
  end

  # Generates the video podcast feed.
  class RssGenerator
    # Creates the RssGenerator given a config as specified by
    # Database.init_database and an instanstance of Database
    def initialize(config, db)
      @config = config
      @db = db
    end

    # Generates the RSS and returns it as a string.
    def generate()
      # Here is where I would generate RSS and also clean up older files
      rss = RSS::Maker.make("2.0") do |maker|
        maker.channel.title = @config['show_name']
        maker.channel.description = "My " + @config['show_name'] + " RSS feed"
        maker.channel.link = @config['rss_link']
        maker.channel.lastBuildDate = Time.now

        maker.channel.itunes_author = maker.channel.title
        maker.channel.itunes_owner.itunes_name=@config['rss_ownername']
        maker.channel.itunes_owner.itunes_email=@config['rss_owneremail']
        
        maker.items.do_sort = true

        @db.shows_by_configid(@config['id']) do |show|
          maker.items.new_item do |item|
            item.title = show['s_ep_title']
            item.link = URI.escape(@config['rss_baseurl'] + show['filename'])

            item.guid.content = item.link
            item.guid.isPermaLink = true
            item.pubDate = Time.at(show['s_ep_timecap'])
            item.description = show['s_ep_description']
            item.itunes_summary = show['s_ep_description']
            item.itunes_explicit = "No"

            # I need to come back and do the time.  For now, I'm hard coding
            # to 32 minutes
            # time = show['s_ep_length']
            item.itunes_duration =
              TiVo::TiVoVideo.human_duration(show['s_ep_length'])

            item.enclosure.url = item.link
            item.enclosure.length = File.size(show['filename'])
            item.enclosure.type = 'video/x-m4v'
          end
        end
      end

      return rss.to_s
    end
  end
end


# Local Variables:
# mode: ruby
# End:
