#!/usr/bin/env ruby

# Adds the lib path next to the path the script is in to the head of
# the search patch
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib',
                                      'httpclient-2.1.2', 'lib'))
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'sqlite3'
require 'rss'
require 'uri'
BASE_URL = 'http://temp.kgarner.com/tdstest/'

# Open up the database we use for status
db = SQLite3::Database.new("tivodownload.db")
db.results_as_hash = true

# Here is where I would generate RSS and also clean up older files
rss = RSS::Maker.make("2.0") do |maker|
  maker.channel.title = "The Daily Show"
  maker.channel.description = "My Daily Show RSS feed"
  maker.channel.link = "http://www.thedailyshow.com/"
  maker.channel.lastBuildDate = Time.now

  maker.channel.itunes_author = maker.channel.title
  maker.channel.itunes_owner.itunes_name='Keith Garner'
  maker.channel.itunes_owner.itunes_email='kgarner@kgarner.com'
  
  maker.items.do_sort = true

  db.query("select * from status") do |rows|
    rows.each do |row|
      maker.items.new_item do |item|
        item.title = row['s_ep_title']
        item.link = URI.escape(BASE_URL + row['filename'])

        item.guid.content = item.link
        item.guid.isPermaLink = true
        item.pubDate = Time.parse(row['s_ep_timecap'])
        item.description = row['s_ep_description']
        item.itunes_summary = row['s_ep_description']
        item.itunes_explicit = "No"

        # I need to come back and do the time.  For now, I'm hard coding
        # to 32 minutes
        # time = row['s_ep_length']
        item.itunes_duration = '32:00'

        item.enclosure.url = item.link
        item.enclosure.length = File.size(row['filename'])
        item.enclosure.type = 'video/x-m4v'
      end
    end
  end
end

File.open('rss.xml', 'w') { |f| f << rss.to_s }

db.close
