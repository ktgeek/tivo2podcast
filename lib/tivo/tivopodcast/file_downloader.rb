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
  class ShowDownloader
    def initialize(config)
      @config = config
    end

    def tivo
      @config.tivo_factory
    end

    def download_show(show, name)
      IO.popen("java -jar #{@config.tivolibre} -m #{@config.mak} -o \"#{name}\"", 'wb') do |td|
        pbar = ANSI::ProgressBar.new(name, show.size) if @config.verbose
        tivo.download_show(show) do |tc|
          td << tc
          pbar.inc(tc.length) unless pbar.nil?
        end
        unless pbar.nil?
          pbar.finish
          puts
        end
      end
    end
  end
end
