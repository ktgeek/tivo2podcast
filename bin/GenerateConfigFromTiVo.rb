#!/usr/bin/env ruby
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


# Adds the lib path next to the path the script is in to the head of
# the search patch
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib',
                                      'tivo'))

begin
  require 'rubygems'
rescue LoadError
  # Ruby gems wasn't found, maybe someone loaded the prereqs directly
  # Not an error, but we'll swallow it for now.
end
require 'tivopodcast/database'
require 'optparse'
require 'TiVo'
require 'TiVo-utils'
require 'tivopodcast/config'
require 'highline'
require 'pp'

URL_REGEXP = /http:\/\/([\w+?\.\w+])+([a-zA-Z0-9\~\!\@\#\$\%\^\&amp;\*\(\)_\-\=\+\\\/\?\.\:\;\'\,]*)?/i

t2pconfig = Tivo2Podcast::Config.new

opts = OptionParser.new
opts.on('-m MAK', '--mak MAK',
        'The TiVo\'s media access key') { |k| t2pconfig.mak = k }
opts.on('-t ADDR', '--tivo_addr ADDR',
        'The hostname or IP address of the tivo to get the data from') do |t|
  t2pconfig.tivo_addr = t
end
opts.on('-v', '--verbose') { t2pconfig.verbose = true }
opts.on_tail('-h', '--help', 'Show this message') do
  puts opts
  exit
end
opts.parse(ARGV)

Tivo2Podcast::connect_database((ENV['TIVO2PODCASTDIR'].nil? ? ENV['HOME'] :
                                ENV['TIVO2PODCASTDIR']) +
                               File::SEPARATOR + '.tivo2podcast.db')

tivo = t2pconfig.tivo_factory

basis = TiVo::Utils::do_menu(tivo.get_listings)

printf("\n\n")
hl = HighLine.new
required_response_proc = Proc.new { |answer| !(answer.nil? || answer.empty?) }
basis.each do |show|
  puts "Creating a configuration for #{show.title}"
  sconfig = Tivo2Podcast::Db::Config.new
  sconfig.config_name = hl.ask('Config name:') do |q|
    q.default = show.title.delete(' ')
  end
  sconfig.show_name = hl.ask('Show name:') do |q|
    q.default = show.title
  end
#  sconfig.rss_link = hl.ask('Show info URL:') do |q|
#    q.validate = URL_REGEXP
#  end
#  sconfig.rss_filename = hl.ask('RSS Filename:') do |q|
#    q.default = show.title.delete(' ').downcase + ".xml"
#  end
#  sconfig.rss_baseurl = hl.ask('RSS Base URL:') do |q|
#    q.default = t2pconfig['baseurl']
#    q.validate = URL_REGEXP
#  end
  # sconfig.rss_ownername = hl.ask('RSS owner name:') do |q|
  #   q.validate = required_response_proc
  # end
  # sconfig.rss_owneremail = hl.ask('RSS owner e-mail:') do |q|
  #   q.validate = required_response_proc
  # end
  sconfig.ep_to_keep = hl.ask('Episodes to keep in the feed:', Integer) do |q|
    q.default = 4
  end
  sconfig.encode_crop = hl.ask('Encode crop:')
  sconfig.encode_audio_bitrate = hl.ask('Audio bitrate in K:', Integer) do |q|
    q.default = 48
  end
  sconfig.encode_video_bitrate = hl.ask('Video bitrate in K:', Integer) do |q|
    q.default = 768
  end
  sconfig.max_width = hl.ask('Max video width?', Integer) do |q|
    q.default = 960
  end

  # I want to let this be null, but you can't do that with an Integer.
  # We'll revisit that later
#  sconfig['max_height'] = hl.ask('Max video height?', Integer)

  sconfig.encode_decomb = hl.agree('Decomb/deinterlace? (yes/no)') ? 1 : 0

  pp sconfig
  sconfig.save
end  
