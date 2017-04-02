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
require 'facets/enumerable/accumulate'
require 'TiVo'
require 'tivopodcast/database'

module Tivo2Podcast
  # Generates the video podcast feed.
  class RssGenerator
    def self.regenerate_rss_files
      rss_files = Tivo2Podcast::RssFile.all
      self.generate_from_rssfiles(rss_files)
    end

    def self.generate_from_config(config)
      self.generate_from_rssfiles(config.rss_files)
    end

    def self.generate_from_configs(configs)
      self.generate_from_rssfiles(configs.accumulate.rss_files)
    end

    def self.generate_from_rssfiles(rssfiles)
      rssfiles.each do |rss_file|
        rss = self.new(rss_file).make_rss

        File.open(rss_file.filename, 'w') { |f| f << rss.to_s }
      end
    end

    def initialize(rss_file)
      @rss_file = rss_file
    end

    def make_rss
      RSS::Maker.make("2.0") do |maker|
        configure_channel(maker.channel)
        maker.items.do_sort = true
        shows = Tivo2Podcast::Show.on_disk.for_config(@rss_file.configs).order(:time_captured)
        shows.each { |s| add_item(maker.items, s) }
      end
    end

    private
    def configure_channel(channel)
      channel.title = @rss_file.feed_title
      channel.description = @rss_file.feed_description
      channel.link = @rss_file.link
      channel.lastBuildDate = Time.now

      channel.itunes_author = channel.title
      channel.itunes_owner.itunes_name = @rss_file.owner_name
      channel.itunes_owner.itunes_email = @rss_file.owner_email
    end

    def item_title(size, show)
      size > 1 ? "#{show.name}: #{show.episode_title}" : show.episode_title
    end

    def add_item(items, show)
      # If the file got removed and no one ran a database clean
      # let's not add it to the RSS feed.
      return unless File.exist?(show.filename)
      items.new_item do |item|
        item.title = item_title(@rss_file.configs.size, show)
        item.link = URI.escape("#{@rss_file.base_url}#{show.filename}")

        item.guid.content = item.link
        item.guid.isPermaLink = true
        item.pubDate = Time.at(show.time_captured)
        item.description = show.description
        item.itunes_summary = show.description
        item.itunes_explicit = "No"

        item.itunes_duration =
          TiVo::TiVoVideo.human_duration(show.length)

        item.enclosure.url = item.link
        item.enclosure.length = File.size(show.filename)
        item.enclosure.type = 'video/x-m4v'
      end
    end
  end
end

# Local Variables:
# mode: ruby
# End:
