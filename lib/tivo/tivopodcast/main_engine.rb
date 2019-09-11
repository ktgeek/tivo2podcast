# frozen_string_literal: true

# Copyright 2015-2016 Keith T. Garner. All rights reserved.
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
require 'tivopodcast/notifier'
require 'tivopodcast/transcoder'
require 'tivopodcast/database'
require 'tivopodcast/rss_generator'
require 'tivopodcast/main_engine_work_orders'
require 'tivopodcast/file_downloader'

module Tivo2Podcast
  class MainEngine
    def initialize(t2pconfig = nil)
      @t2pconfig = t2pconfig || Tivo2Podcast::AppConfig.instance
      @tivos_by_name = {}
    end

    def create_work_thread(queue)
      raise ArgumentError unless queue
      Thread.new do
        loop do
          work_order = queue.deq
          break if work_order.type == :NO_MORE_WORK
          work_order.do_work
        end
      end
    end

    def create_show_base_filename(show)
      name = String.new "#{show.title}-#{show.time_captured.strftime('%Y%m%d%H%M')}"
      name << "-#{show.episode_title}" if show.episode_title
      name << "-#{show.episode_number}" if show.episode_number
      name.gsub(%r{[:\?\$/;#]}, '_')
    end

    def configs
      config_names = @t2pconfig.opt_config_names
      if config_names.nil? || config_names.empty?
        Tivo2Podcast::Config.all
      else
        Tivo2Podcast::Config.for_name(config_names)
      end
    end

    def get_shows_to_process(tivo, config)
      shows = tivo.get_shows_by_name(config.show_name)
      # Only work on the X latest shows.  That way if there are 10
      # on the tivo, but we only want to keep 4, we don't encode 6
      # of them just to throw them out later in the cleanup phase.
      shows = shows.reverse[0, config.episodes_to_keep].reverse if shows.size > config.episodes_to_keep
      shows
    end

    def tivo_for_name(name)
      return @t2pconfig.tivo_factory if @t2pconfig.tivo_address || name.nil?
      @tivos_by_name[name] ||= begin
        tivo_address = TiVo.locate_via_dnssd(name)
        TiVo::TiVo.new(tivo_address, @t2pconfig.mak)
      end
    end

    # This method is doing WAY WAY WAY too much
    def normal_processing
      work_thread = create_work_thread(work_queue)

      configs.each do |config|
        tivo = tivo_for_name(config.tivo)
        shows = get_shows_to_process(tivo, config)

        # So starts the giant loop that processes the shows...
        process_shows(tivo, config, shows)

        work_queue.enq(CleanupWorkOrder.new(config))
      end

      work_queue.enq(NoMoreWorkOrder.new)
      work_thread.join
      Tivo2Podcast::NotifierEngine.instance.shutdown
    end

    private

    def process_shows(tivo, config, shows)
      shows.each do |show|
        basename = create_show_base_filename(show)
        download = "#{basename}.ts"
        transcode = "#{basename}.m4v"

        notifier = Tivo2Podcast::NotifierEngine.instance
        if !Tivo2Podcast::Show.episode_for(config, show.program_id).exists?
          begin
            notifier.notify("Starting download of #{basename}")
            # If the file exists, we'll assume the download went okay
            # Shame on us for not checking if it isn't
            unless File.exist?(download)
              downloader = ShowDownloader.new(@t2pconfig, tivo)
              downloader.download_show(show, download)
            end

            notifier.notify("Finished download of #{basename}")

            work_queue.enq(TranscodeWorkOrder.new(config, show, basename, download, transcode))

            # Adding a 30 second delay before the next download to
            # see if it helps with our download issues
            sleep 30
          rescue IOError => e
            # If there was an IOError, we'll assume a file turd of
            # some sort was left behind and clean it up
            File.delete(download) if File.exist?(download)
            notifier.notify("Error downloading #{basename}: #{e}")
          end
        elsif @t2pconfig.verbose
          puts "Skipping #{basename} (#{show.program_id}) because it seems to exist"
        end
      end
    end

    def work_queue
      @work_queue ||= Queue.new
    end
  end
end

# Local Variables:
# mode: ruby
# End:
