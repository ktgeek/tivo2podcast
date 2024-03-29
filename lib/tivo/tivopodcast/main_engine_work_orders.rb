# frozen_string_literal: true

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

        transcoder.skip_commercials(@basename, @transcode)

        File.rm_f(@download)

        Tivo2Podcast::Show.create_from_config_show_filename(@config, @show, @transcode)
        notifier.notify("Finished transcode of #{@basename}")
      end
    end

    class CleanupWorkOrder < WorkOrder
      def initialize(config)
        super(config)
        @type = :CLEANUP
      end

      def do_work
        shows_to_clean = Tivo2Podcast::Show.on_disk.for_config(@config).order(time_captured: :desc)
                                           .offset(@config.episodes_to_keep)

        shows_to_clean.each do |show|
          # If the file doesn't exist, don't try to delete, but
          # setting on_disk to false is appropriate.
          File.rm_f(show.filename)
          show.on_disk = false
          show.save!
        end

        # We might want these to move...or to rename this object to
        # something more sane.
        Tivo2Podcast::RssGenerator.generate_from_config(@config)
        # Put notification here
        Tivo2Podcast::NotifierEngine.notify("Finished processing #{@config.name}")
      end
    end
  end
end
