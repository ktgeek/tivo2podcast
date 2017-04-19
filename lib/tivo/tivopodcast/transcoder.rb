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

require 'tivopodcast/ffi-mp4v2'

module Tivo2Podcast
  # This class encapsulates both calling out to handbrake to doing the
  # transcoding from source mpg to iPhone friendly m4v, as well as
  # calling out to AtomicParsley to add the video metadata to the file.
  class Transcoder
    # show is assumed to be an instance of TiVo::TiVoVideo which holds
    # the metadata of the show to be transcoded.
    def initialize(config, show)
      @config = config
      @show = show
    end

    def preset
      @config.handbrake_config || 'iPad'
    end

    def add_chapter_info(m4vfilename, chapfilename)
      m4vfile = Mp4v2::mp4_modify(m4vfilename)

      duration = Mp4v2::mp4_get_duration(m4vfile)
      time_scale = Mp4v2::mp4_get_time_scale(m4vfile)
      # This should get us total_length in seconds
      total_length = duration / time_scale

      # Add the chapter track, have it reference the first track
      # (should be the video) and set the "clock ticks per second" to 1.
      # (We may want to set that to 1000 to go into milliseconds.)
      chapter_track = Mp4v2::mp4_add_chapter_text_track(m4vfile, 1, 1)

      re = /^AddChapterBySecond\((\d+),/
      last_time = 0
      File.open(chapfilename) do |f|
        f.each_line do |l|
          md = re.match(l.chomp)
          if md && ((t = md[1].to_i) > 0)
            Mp4v2::mp4_add_chapter(m4vfile, chapter_track, t - last_time)
            last_time = t
          end
        end
      end

      remaining = total_length - last_time
      Mp4v2::mp4_add_chapter(m4vfile, chapter_track, remaining) if remaining > 0

      Mp4v2::mp4_close(m4vfile)
      Mp4v2::mp4_optimize(m4vfilename)
    end

    # This transcodes and properly tags the show.  infile is the
    # filename of the sourcefile, outfile is the filename to transcode
    # to
    def transcode_show(infile, outfile)
      t2pconfig = Tivo2Podcast::AppConfig.instance
      command = "#{t2pconfig.handbrake} -v0 --preset-import-gui -Z \"#{preset}\" " \
                "-i \"#{infile}\" -o \"#{outfile}\""
      command << " >/dev/null 2>&1" unless t2pconfig.verbose

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
      showtitle = "#{@show.title}: #{@show.episode_title(use_date_if_nil: true)}"
      showtitle << " (#{@show.episode_number})" unless @show.episode_number.nil?

      command = "#{t2pconfig.atomicparsley} \"#{outfile}\" -W " \
                "--title \"#{showtitle}\" --TVShowName \"#{@show.title}\" " \
                "--TVEpisode \"#{@show.episode_title(use_date_if_nil: true)}\" " \
                "--artist \"#{@show.title}\""
      command << " --TVEpisodeNum #{@show.episode_number}" unless @show.episode_number.nil?
      command << %/ --TVNetwork "#{@show.station}"/ unless @show.station.nil?
      if @show.description
        desc = @show.description.gsub(/"/, '\"')
        command << %/ --description "#{@desc}"/
      end
      command << ' >/dev/null 2>&1' unless t2pconfig.verbose
      returncode = system(command)
      if !returncode
        puts "something isn't working right, bailing"
        puts "Command that failed: " + command
        # TODO: change this to an exception
        exit(1)
      end
    end

    def skip_commercials(basename, transcode)
      t2pconfig = Tivo2Podcast::AppConfig.instance
      command = %/#{t2pconfig.comskip} --ini=#{t2pconfig.comskip_ini} -q "#{transcode}"/
      command << " >/dev/null 2>&1" unless t2pconfig.verbose

      returncode = system(command)
      # Comskip doesn't seem to do the 0 return code (or is that wine?)
      # For now we'll just check to see if there is a > 0 length .chp file
      # if !returncode
      #   puts "something isn't working right, bailing"
      #   puts "Command that failed: " + command
      #   # TODO: Change this to an exception
      #   exit(1)
      # end

      chpfile = "#{basename}.chp"
      add_chapter_info(transcode, chpfile)

      File.delete(chpfile) if File.exist?(chpfile)
      File.delete(basename + ".log") if File.exist?(basename + ".log")
    end
  end
end

# Local Variables:
# mode: ruby
# End:
