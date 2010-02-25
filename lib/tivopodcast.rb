# This file contains the functions that the main script needs broken into 
require 'sqlite3'
require 'TiVo'

module Tivo2Podcast
  # Database access facade for the state information between script runs
  class T2PDatabase
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
      @db.execute_batch('create table configs (
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
                     encode_decomb INTEGER
                   );
                   create table shows (
                     id INTEGER PRIMARY KEY AUTOINCREMENT,
                     configid TEXT NOT NULL,
                     s_name TEXT,
                     s_ep_title TEXT,
                     s_ep_number TEXT,
                     s_ep_description TEXT,
                     s_ep_length INTEGER,
                     s_ep_timecap INTEGER,
                     filename TEXT UNIQUE,
                     FOREIGN KEY(configid) REFERENCES configs(id)
                   );')
    end

    # Gets the configs from the config table, by default it will get all unless
    # an array of names is passed in.
    def get_configs(names=nil)
      result = Array.new
      if names.nil? || names.empty?
        @db.query("select * from configs") { |rs| rs.each { |r| result << r } }
      else
        names.each do |n|
          @db.query("select * from configs where config_name = ?", n) do |rs|
            rs.each { |r| result << r }
          end
        end
      end
      return result
    end

    # Select all the shows for a given config id
    def shows_by_configid(id, &block)
      @db.query("select * from shows where configid=?", id) do |rows|
        rows.each { |row| yield row }
      end
    end

    # Add a show to the database for a given config and video stored
    # in the given filename
    def add_show(show, config, filename)
      ps = @db.prepare('insert into shows(configid, s_name, s_ep_title, s_ep_number, s_ep_description, s_ep_length, s_ep_timecap, filename) values (?, ?, ?, ?, ?, ?, ?, ?);')
      ps.execute(config['id'], show.title, show.episode_title(true),
             show.episode_number, show.description, show.duration,
             show.time_captured.to_i, filename)
      ps.close()
    end

    # Cleans up shows that go over the keep threshold specified in the config
    def show_cleanup(config)
      filenames = Array.new\
      @db.execute('create temp table cleanup_temp as select id,filename from shows where configid=? order by s_ep_timecap desc;', config['id'])
      @db.query('select id,filename from cleanup_temp where rowid>?',
                config['ep_to_keep']) do |results|
        results.each do
          |r| filenames << r['filename']
          @db.execute('delete from shows where id=?;', r['id'])
        end
      end
      # Yes, its only in memory, but we may be called many times in here.
      @db.execute('drop table cleanup_temp;')
      return filenames
    end
      
  end

  # This class encapsulates both calling out to handbrake to doing the
  # transcoding from source mpg to iPhone friendly m4v, as well as
  # calling out to AtomicParsley to add the video metadata to the file.
  #
  # This class assumes there is a CONFIG global with information on where
  # to find various binaries.
  class Transcoder
    attr_writer :crop, :audio_bitrate, :video_bitrate

    # config is assumed to be a HashTable with the configuration information
    # as sepecified in T2PDatabase.init_database (I should probably turn
    # configuration into an object.)
    #
    # show is assumed to be an instance of TiVo::TiVoVideo which holds
    # the metadata of the show to be transcoded.
    def initialize(show_config, show)
      @show_config = show_config
      @show = show
      @crop = nil
      @audio_bitrate = nil
      @video_bitrate = nil
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

    def decomb?
      decomb = @decomb.nil? ? @show_config['encode_decomb'] : @decomb
      (decomb.nil? || decomb == 0) ? false : true
    end

    # This transcodes and properly tags the show.  infile is the
    # filename of the sourcefile, outfile is the filename to transcode
    # to
    def transcode_show(infile, outfile)
      command = "#{CONFIG.handbreak} -v0 -e x264 -b#{video_bitrate.to_s} -2 -T"
      command += ' -5 default' if decomb?
      command += " --crop #{crop}" unless crop.nil?
      command += " -a 1 -E faac -B#{audio_bitrate.to_s} -6 stereo -R 48 " +
        '-D 0.0 -f mp4 -X 480 -x ' +
        'cabac=0:ref=2:me=umh:bframes=0:subme=6:8x8dct=0:trellis=0 ' +
        "-i \"#{infile}\" -o \"#{outfile}\""
      command += " >/dev/null 2>&1" unless CONFIG.verbose
                                  
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

      command = "#{CONFIG.atomicparsley} \"#{outfile}\" -W " +
        "--title \"#{showtitle}\" --TVShowName \"#{@show.title}\" " +
        "--TVEpisode \"#{@show.episode_title(true)}\""
      command += " --TVEpisodeNum #{@show.episode_number}" unless @show.episode_number.nil?
      command += " --TVNetwork \"#{@show.station}\"" unless @show.station.nil?
      command += " --description \"#{@show.description}\"" unless @show.description.nil?
      command += ' >/dev/null 2>&1' unless CONFIG.verbose
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
    # T2PDatabase.init_database and an instanstance of T2PDatabase
    def initialize(config, db)
      @config = config
      @db = db
    end

    # Generates the RSS and returns it as a string.
    def generate()
      # Here is where I would generate RSS and also clean up older files
      rss = RSS::Maker.make("2.0") do |maker|
        maker.channel.title = @config['show_name']
        maker.channel.description = "My " + @config['show_name'] + "how RSS feed"
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
            item.itunes_duration = '32:00'

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
