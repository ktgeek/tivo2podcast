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
    def initialize(config, aggregate = false)
      @config = config
      @aggregate = aggregate
    end

    # Generates the RSS and returns it as a string.
    def generate()
      # Here is where I would generate RSS and also clean up older files
      rss = RSS::Maker.make("2.0") do |maker|
        maker.channel.title = @config.show_name
        maker.channel.description = "My " + @config.show_name + " RSS feed"
        maker.channel.link = @config.rss_link
        maker.channel.lastBuildDate = Time.now

        maker.channel.itunes_author = maker.channel.title
        maker.channel.itunes_owner.itunes_name=@config.rss_ownername
        maker.channel.itunes_owner.itunes_email=@config.rss_owneremail
        
        maker.items.do_sort = true

        buildp = lambda do |show|
          maker.items.new_item do |item|
            unless @aggregate
              item.title = show.s_ep_title
            else
              item.title = show.s_name + ": " + show.s_ep_title
            end
            item.link = URI.escape(@config.rss_baseurl + show.filename)

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
          
        unless @aggregate
          Tivo2Podcast::Db::Show.where(:configid => @config.id,
                                       :on_disk => 1).all.each &buildp
        else
          Tivo2Podcast::Db::Show.where(
              :configid => Tivo2Podcast::Db::Config.where(:aggregate => 1),
              :on_disk => 1).order(:id).each &buildp
        end
      end

      return rss.to_s
    end
  end
end

# Local Variables:
# mode: ruby
# End:
