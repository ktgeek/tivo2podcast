#!/usr/bin/env ruby
# Copyright 2011-2016 Keith T. Garner. All rights reserved.
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


# Adds the lib path next to the path the script is in to the head of
# the search patch
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'tivo'))

require 'tivopodcast/database'
require 'optparse'
require 'TiVo'
require 'TiVo-utils'
require 'tivopodcast/config'
require 'tty-prompt'

def video_menu(videos)
  menu_entries = videos.map do |video|
    [
      "%3d | %-43.43s | %13.13s | %5s\n" % [
        video.channel,
        video.printable_title,
        video.time_captured.strftime('%m/%d %I:%M%p'),
        video.human_duration
      ],
      video
    ]
  end
  prompt = TTY::Prompt.new
  prompt.multi_select("Choose programs to use as templates", per_page: 10, echo: false) do |menu|
    menu_entries.each { |e| menu.choice *e }
  end
end

t2pconfig = Tivo2Podcast::AppConfig.instance

opts = OptionParser.new
opts.on('-m MAK', '--mak MAK',
        'The TiVo\'s media access key') { |k| t2pconfig.mak = k }
opts.on('-t ADDR', '--tivo_addr ADDR',
        'The hostname or IP address of the tivo to get the data from') do |t|
  t2pconfig.tivo_addr = t
end
opts.on('-n NAME', '--tivo_name NAME',
        'The name assigned to the tivo via the my.tivo service') do |n|
  t2pconfig.tivo_name = n
end
opts.on('-v', '--verbose') { t2pconfig.verbose = true }
opts.on_tail('-h', '--help', 'Show this message') do
  puts opts
  exit
end
opts.parse(ARGV)

Tivo2Podcast::connect_database(Tivo2Podcast::AppConfig::DATABASE_FILENAME)

tivo = t2pconfig.tivo_factory

basis = video_menu(tivo.get_listings.videos)

prompt = TTY::Prompt.new
basis.each do |show|
  puts "Creating a configuration for #{show.title}"
  sconfig = Tivo2Podcast::Config.new
  sconfig.config_name = prompt.ask('Config name:', default: show.title.delete(' '))
  sconfig.show_name = prompt.ask('Show name:', default: show.title)
  sconfig.ep_to_keep = prompt.ask('Episodes to keep in the feed:', convert: :int, default: 4)
  sconfig.encode_crop = prompt.ask('Encode crop:')
  sconfig.encode_audio_bitrate = prompt.ask('Audio bitrate in K:', convert: :int, default: 128)
  sconfig.encode_video_bitrate = prompt.ask('Video bitrate in K:', convert: :int, default: 1546)
  sconfig.max_width = prompt.ask('Max video width:', convert: :int, default: 1280)

  sconfig.encode_decomb = prompt.yes?('Decomb/deinterlace? ') ? 1 : 0

  sconfig.save
  printf("Saved!\n\n")
end
