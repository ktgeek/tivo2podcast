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
module Tivo2Podcast
  class MainEngine
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
        @show = show
        @basename = basename
        @download = download
        @transcode = transcode
        @type = :TRANSCODE
      end

      def do_work
        # I need config, s/show, basename, download, transcode
        notifier = Tivo2Podcast::NotifierEngine.instance
        notifier.notify("Starting transcode of #{@basename}")

        transcoder = Tivo2Podcast::Transcoder.new(@config, @show)
        transcoder.transcode_show(@download, @transcode)

        transcoder.skip_commercials(@basename, @download, @transcode)

        File.delete(@download) if File.exist?(@download)

        show =
          Tivo2Podcast::Show.new_from_config_show_filename(@config, @show, @transcode)
        show.save!
        notifier.notify("Finished transcode of #{@basename}")
      end
    end

    class CleanupWorkOrder < WorkOrder
      def initialize(config)
        super(config)
        @type = :CLEANUP
      end

      def do_work
        # TODO: Recraft this from two queries into one.  Probably
        # change from newest_shows to shows_to_nuke using .offset(@config.ep_to_keep)
        newest_shows = Tivo2Podcast::Show.where(configid: @config, on_disk: true)
          .order(s_ep_timecap: :desc).limit(@config.ep_to_keep)
        unless newest_shows.nil? || newest_shows.empty?
          Tivo2Podcast::Show.where(configid: @config, on_disk: true)
            .where.not(id: newest_shows).each do |show|
            # If the file doesn't exist, don't try to delete, but
            # still setting the on_disk to false is appropriate.
            File.delete(show.filename) if File.exist?(show.filename)
            show.on_disk = false
            show.save!
          end
        end

        # We might want these to move...or to rename this object to
        # something more sane.
        Tivo2Podcast::RssGenerator.generate_from_config(@config)
        # Put notification here
        Tivo2Podcast::NotifierEngine.instance.notify(
          "Finished processing #{@config.config_name}")
      end
    end
  end
end
