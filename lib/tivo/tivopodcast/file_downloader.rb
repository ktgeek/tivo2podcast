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

    def download_show(show, name)
      tivo = @config.tivo_factory

      download_tivolibre(tivo, show, name)
    end

    # TivoLibre has a bug that won't let us downcode as we stream it
    # down in the 0.7.3 release.  Once they upgrade it we can stream
    # it on the way down.
    def download_tivolibre(tivo, show, name)
      temp_name = "#{name}.ts"
      if @config.verbose
        pbar = ANSI::ProgressBar.new(name, show.size)
        File.open(temp_name, 'wb') do |file|
          tivo.download_show(show) do |tc|
            file << tc
            pbar.inc(tc.length) unless pbar.nil?
          end
        end
        pbar.finish unless pbar.nil?
        puts unless pbar.nil?
      else
        tivo.download_show(show, filename: temp_name)
      end

      command =
        "java -jar #{@config.tivolibre} -i \"#{temp_name}\" -o \"#{name}\" -m #{@config.mak}"
      puts command if @config.verbose
      returncode = system(command)
      if !returncode
        puts "something isn't working right, bailing"
        puts "Command that failed: " + command
        # TODO: change this to an exception
        exit(1)
      end

      File.delete(temp_name) if File.exist?(temp_name)
    end

  end
end
