# -*- coding: utf-8 -*-
# Copyright 2011 Keith T. Garner. All rights reserved.
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
require 'set'
require 'thread'
require 'ansi/progressbar'
require 'tivopodcast/notifier'
require 'tivopodcast/transcoder'
require 'tivopodcast/database'
require 'tivopodcast/rss_generator'

module Tivo2Podcast
  class MainEngine
    def initialize(config)
      @config = config
      @db = Tivo2Podcast::Database.new((ENV['TIVO2PODCASTDIR'].nil? ?
                                        ENV['HOME'] :
                                        ENV['TIVO2PODCASTDIR']) +
                                       File::SEPARATOR + '.tivo2podcast.db')
      @notifier = TiVo2Podcast::NotifierEngine.new(@config)
    end

    class WorkOrder
      attr_reader :type, :config
      def initialize(config)
        @config = config
        @type = nil
      end
    end

    class NoMoreWorkOrder < WorkOrder
      def initialize
        super(nil)
        @type = :NO_MORE_WORK
      end
    end
    
    class TranscodeWorkOrder < WorkOrder
      attr_reader :show, :basename, :download, :transcode

      def initialize(config, show, basename, download, transcode)
        super(config)
        @show, @basename = show, basename
        @download, @transcode = download, transcode
        @type = :TRANSCODE
      end
    end

    class CleanupWorkOrder < WorkOrder
      def initialize(config)
        super(config)
        @type = :CLEANUP
      end
    end

    # This method feels like its still doing too much...
    def create_work_thread(queue)
      raise ArgumentError if queue.nil?
      Thread.new do
        loop do
          tc = queue.deq

          case tc.type
          when :NO_MORE_WORK
            break;

          when :TRANSCODE
            # I need config, s/show, basename, download, transcode

            @notifier.notify("Starting transcode of #{tc.basename}")
          
            transcoder = Tivo2Podcast::Transcoder.new(@config, tc.config, tc.show)
            transcoder.transcode_show(tc.download, tc.transcode)

            transcoder.skip_commercials(tc.basename, tc.download, tc.transcode)
            
            File.delete(tc.download) if File.exists?(tc.download)

            @db.add_show(tc.show, tc.config, tc.transcode)
            @notifier.notify("Finished transcode of #{tc.basename}")

          when :CLEANUP
            deletes = @db.old_show_cleanup(tc.config)
            deletes.each { |f| File.delete(f) }

            create_rss(tc.config)
            # Put notification here
            @notifier.notify("Finished processing #{tc.config['config_name']}")
          end
        end
      end
    end

    def download_show(show, name)
      tivo = @config.tivo_factory

      # downlaod the file
      IO.popen("#{@config.tivodecode} -n -o \"#{name}\" -", 'wb') do |td|
        pbar = @config.verbose ? ANSI::ProgressBar.new(name, show.size) : nil
        tivo.download_show(show) do |tc|
          td << tc
          pbar.inc(tc.length) unless pbar.nil?
        end
        pbar.finish unless pbar.nil?
        puts
      end
    end

    def create_rss(config, aggregate=false)
      rss = Tivo2Podcast::RssGenerator.new(config, @db, aggregate)
      File.open(config['rss_filename'], 'w') { |f| f << rss.generate() }
    end

    def normal_processing
      configs = @db.get_configs(@config.opt_config_names)

      tivo = @config.tivo_factory

      work_queue = Queue.new
      work_thread = create_work_thread(work_queue)
      
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
          basename = s.title + '-' + s.time_captured.strftime("%Y%m%d%H%M")
          basename = basename + '-' + s.episode_title unless s.episode_title.nil?
          basename = basename + '-' + s.episode_number unless s.episode_number.nil?
          basename.gsub!(/[:\?]/, '_')

          download = basename + ".mpg"
          transcode = basename + ".m4v"

          # We'll need the later condition until everything has a program_id
          # (this is only for my own migration.)
          unless (@db.got_show?(config, s) || File.exist?(transcode))
            @notifier.notify("Starting download of #{basename}")
            
            # If the file exists, we'll assume the download went okay
            # Shame on us for not checking if it isn't
            download_show(s, download) unless File.exists?(download)

            @notifier.notify("Finished download of #{basename}")

            # Code was removed here to put into thread
            #   Create arugments for thread
            work_queue.enq(TranscodeWorkOrder.new(config, s, basename,
                                                  download, transcode))
          else
            puts "Skipping #{basename} (#{s.program_id}) because it seems to exist" if @config.verbose
          end
        end

        work_queue.enq(CleanupWorkOrder.new(config))
      end

      # configs are done being worked on here, thereis no more work.
      work_queue.enq(NoMoreWorkOrder.new)

      # Wait for this thread to complete before finishing
      work_thread.join

      # Create the aggregated feed
      create_rss(@config.aggregate_config, true) if @config.aggregate?
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
        create_rss(@config.aggregate_config, true) if @config.aggregate?
      end
    end

    def regenerate_rss_files
      configs = @db.get_configs
      configs.each { |c| create_rss(c) }
      create_rss(@config.aggregate_config, true) if @config.aggregate?
    end
  end
end


# Local Variables:
# mode: ruby
# End: