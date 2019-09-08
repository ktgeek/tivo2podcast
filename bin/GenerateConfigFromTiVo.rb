#!/usr/bin/env ruby
# frozen_string_literal: true

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
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'tivo'))

require 'tivopodcast/database'
require 'optparse'
require 'TiVo'
require 'tivopodcast/config'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

def video_menu(videos)
  menu_entries = videos.reject(&:copy_protected?).map do |video|
    [
      String.format(
        "%3d | %-43.43s | %13.13s | %5s\n",
        video.channel,
        video.printable_title,
        video.time_captured.strftime("%m/%d %I:%M%p"),
        video.human_duration
      ),
      video
    ]
  end
  prompt = TTY::Prompt.new
  prompt.multi_select("Choose programs to use as templates", per_page: 10, echo: false) do |menu|
    menu_entries.each { |e| menu.choice(*e) }
  end
end

TiVoChoice = Struct.new(:name, :tivo)

def get_tivo_choice(t2pconfig)
  return TiVoChoice.new(nil, t2pconfig.tivo_factory) if t2pconfig.tivo_address

  tivos = {}
  spinner = TTY::Spinner.new("#{Pastel.new.green(':spinner')} Locating tivos... ", format: :dots)
  spinner.run do
    tivos = TiVo.tivos_via_dnssd
  end

  # rubocop:disable Style/StderrPuts
  if tivos.empty?
    $stderr.puts("No TiVos found")
    exit(1)
  end
  # rubocop:enable Style/StderrPuts

  if tivos.size > 1
    prompt = TTY::Prompt.new
    selection = prompt.select("Please choose a TiVo: ", tivos.to_a.index_by { |a| a[0] })
  else
    selection = tivos.first
  end

  tivo = TiVo::TiVo.new(selection[1], t2pconfig.mak)

  TiVoChoice.new(selection[0], tivo)
end

t2pconfig = Tivo2Podcast::AppConfig.instance

opts = OptionParser.new
opts.on('-m MAK', '--mak MAK',
        'The TiVo\'s media access key') { |k| t2pconfig.mak = k }
opts.on('-t ADDR', '--tivo_address ADDR',
        'The hostname or IP address of the tivo to get the data from. ' \
        'If set, this overrides any show config settings.') do |t|
  t2pconfig.tivo_address = t
end
opts.on('-v', '--verbose') { t2pconfig.verbose = true }
opts.on_tail('-h', '--help', 'Show this message') do
  puts opts
  exit
end
opts.parse(ARGV)

Tivo2Podcast.connect_database(Tivo2Podcast::AppConfig::DATABASE_FILENAME)

tivo_choice = get_tivo_choice(t2pconfig)

basis = video_menu(tivo_choice.tivo.get_listings.videos)

prompt = TTY::Prompt.new
basis.each do |show|
  puts "Creating a configuration for #{show.title}"
  sconfig = Tivo2Podcast::Config.new
  sconfig.name = prompt.ask('Config name:', default: show.title.delete(' '))
  sconfig.show_name = prompt.ask('Show name:', default: show.title)
  sconfig.episodes_to_keep =
    prompt.ask('Episodes to keep in the feed:', convert: :int, default: 4)
  sconfig.handbrake_config = prompt.ask('HandBrake config:')
  sconfig.tivo = tivo_choice.name

  printf("Saved!\n\n") if sconfig.save
end
