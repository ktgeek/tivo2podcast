# -*- coding: utf-8 -*-
# Copyright 2015 Keith T. Garner. All rights reserved.
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
require 'tivopodcast/main_engine_work_orders.rb'

module Tivo2Podcast
  class MainEngine
    def initialize(t2pconfig = nil)
      @t2pconfig = t2pconfig ? t2pconfig : Tivo2Podcast::Config.instance
    end

    def create_work_thread(queue)
      raise ArgumentError if queue.nil?
      Thread.new do
        loop do
          work_order = queue.deq
          break if work_order.type == :NO_MORE_WORK

          work_order.do_work
        end
      end
    end

    def download_show(show, name)
      tivo = @t2pconfig.tivo_factory

      # downlaod the file
      IO.popen("#{@t2pconfig.tivodecode} -n -o \"#{name}\" -", 'wb') do |td|
        pbar = @t2pconfig.verbose ? ANSI::ProgressBar.new(name, show.size) : nil
        tivo.download_show(show) do |tc|
          td << tc
          pbar.inc(tc.length) unless pbar.nil?
        end
        pbar.finish unless pbar.nil?
        puts
      end
    end

    def create_show_base_filename(show)
      name = "#{show.title}-#{show.time_captured.strftime("%Y%m%d%H%M")}"
      name << "-#{show.episode_title}" unless show.episode_title.nil?
      name << "-#{show.episode_number}" unless show.episode_number.nil?
      name.gsub(/[:\?;]/, '_')
    end

    def get_configs
      config_names = @t2pconfig.opt_config_names
      if config_names.nil? || config_names.empty?
        Tivo2Podcast::Db::Config.all
      else
        Tivo2Podcast::Db::Config.where(config_name: config_names)
      end
    end

    def get_shows_to_process(tivo, config)
      shows = tivo.get_shows_by_name(config.show_name)

      # Only work on the X latest shows.  That way if there are 10
      # on the tivo, but we only want to keep 4, we don't encode 6
      # of them just to throw them out later in the cleanup phase.
      if shows.size > config.ep_to_keep
        shows = shows.reverse[0, config.ep_to_keep].reverse
      end

      shows
    end

    # This method is doing WAY WAY WAY too much
    def normal_processing
      configs = get_configs

      work_queue = Queue.new
      work_thread = create_work_thread(work_queue)

      tivo = @t2pconfig.tivo_factory

      configs.each do |config|
        shows = get_shows_to_process(tivo, config)

        # So starts the giant loop that processes the shows...
        shows.each do |s|
          basename = create_show_base_filename(s)

          download = "#{basename}.mpg"
          transcode = "#{basename}.m4v"

          notifier = Tivo2Podcast::NotifierEngine.instance
          # We'll need the later condition until everything has a program_id
          # (this is only for my own migration.)
          unless (Tivo2Podcast::Db::Show.where(
                    configid: config, s_ep_programid: s.program_id).exists? ||
                  File.exist?(transcode))
            begin
              notifier.notify("Starting download of #{basename}")

              # If the file exists, we'll assume the download went okay
              # Shame on us for not checking if it isn't
              download_show(s, download) unless File.exists?(download)

              notifier.notify("Finished download of #{basename}")

              work_queue.enq(TranscodeWorkOrder.new(config, s, basename,
                                                    download, transcode))

              # Adding a 30 second delay before the next download to
              # see if it helps with our download issues
              sleep 30
            rescue IOError => e
              # If there was an IOError, we'll assume a file turd of
              # some sort was left behind and clean it up
              File.delete(download) if File.exist?(download)
              notifier.notify("Error downloading #{basename}: #{e}")
            end
          else
            puts "Skipping #{basename} (#{s.program_id}) because it seems to exist" if @t2pconfig.verbose
          end
        end

        work_queue.enq(CleanupWorkOrder.new(config))
      end

      work_queue.enq(NoMoreWorkOrder.new)

      work_thread.join
      Tivo2Podcast::NotifierEngine.instance.shutdown
    end

    def file_cleanup
      # Get shows by id,configid,filename
      configs = Set.new
      deleteids = Array.new

      Tivo2Podcast::Db::Show.where(on_disk: true).each do |result|
        unless File.exists?(result.filename)
          puts "#{result.filename} missing, removing from database."
          configs.add(result.config)
          result.on_disk = false
          result.save!
        end
      end

      unless configs.empty?
        Tivo2Podcast::RssGenerator.generate_from_configs(configs)
      end
    end

    def regenerate_rss_files
      rss_files = Tivo2Podcast::Db::RssFile.all
      Tivo2Podcast::RssGenerator.generate_from_rssfiles(rss_files)
    end
  end
end


# Local Variables:
# mode: ruby
# End:
