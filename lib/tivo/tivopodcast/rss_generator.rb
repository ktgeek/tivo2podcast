# -*- coding: utf-8 -*-
# Copyright 2013 Keith T. Garner. All rights reserved.
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
require 'uri'
require 'rss'
require 'rss/itunes'

module Tivo2Podcast
  # Generates the video podcast feed.
  class RssGenerator
    # Creates the RssGenerator given a config as specified by
    # Database.init_database and an instanstance of Database
    def initialize(config)
      @config = config
    end

    # Generates the RSS and writes out the files of each RSS feed touched
    # by the config
    def generate()
      @config.rss_files.each do |rss_file|
        rss = RSS::Maker.make("2.0") do |maker|
          maker.channel.title = rss_file.feed_title
          maker.channel.description = rss_file.feed_description
          maker.channel.link = rss_file.link
          maker.channel.lastBuildDate = Time.now

          maker.channel.itunes_author = maker.channel.title
          maker.channel.itunes_owner.itunes_name = rss_file.owner_name
          maker.channel.itunes_owner.itunes_email = rss_file.owner_email
          
          maker.items.do_sort = true

          buildp = lambda do |show|
            maker.items.new_item do |item|
              if rss_file.configs > 1
                item.title = show.s_name + ": " + show.s_ep_title
              else
                item.title = show.s_ep_title
              end
              item.link = URI.escape(rss_file.rss_baseurl + show.filename)

              item.guid.content = item.link
              item.guid.isPermaLink = true
              item.pubDate = Time.at(show.s_ep_timecap)
              item.description = show.s_ep_description
              item.itunes_summary = show.s_ep_description
              item.itunes_explicit = "No"

              item.itunes_duration =
                TiVo::TiVoVideo.human_duration(show.s_ep_length)

              item.enclosure.url = item.link
              item.enclosure.length = File.size(show.filename)
              item.enclosure.type = 'video/x-m4v'
            end
          end
          
          Tivo2Podcast::Db::Show.where(:configid => rss_file.configs,
                                       :on_disk => true).
            order(:s_ep_timecap).each &buildp
        end

        # this code needs to change to writing the file out.
        File.open(rss_file.filename, 'w') { |f| f << rss.to_s }
      end
    end
  end
end

# Local Variables:
# mode: ruby
# End:
