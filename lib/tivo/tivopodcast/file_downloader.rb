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

require 'tty-progressbar'
require 'tty-screen'
require 'pastel'

module Tivo2Podcast
  class ShowDownloader
    def initialize(config, tivo)
      @config = config
      @tivo = tivo
    end

    def download_show(show, name)
      pbar = progress_bar(name, show.size) if @config.verbose
      IO.popen("java -jar #{@config.tivolibre} -m #{@config.mak} -o \"#{name}\"", 'wb') do |td|
        @tivo.download_show(show) do |tc|
          td << tc
          pbar.advance(tc.length) if pbar
        end
      end
      pbar.finish if pbar
    end

    private

    def progress_bar(name, size)
      # The name of the file shouldn't take up more than one third of
      # the screen minus the word downloading.
      truncate_size = TTY::Screen.width / 3 - 12
      display_name = name.gsub(/(.{#{truncate_size}}).+/, '\1...')

      pastel = Pastel.new
      TTY::ProgressBar.new("Downloading #{display_name} [:bar] :percent",
                       total: size,
                       complete: pastel.green("="),
                       incomplete: pastel.red("="))
    end
  end
end
