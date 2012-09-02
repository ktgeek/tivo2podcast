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
require 'sqlite3'

module Tivo2Podcast
  # Database access facade for the state information between script runs
  class Database
    # filename - The name of the sqlite file.
    def initialize(filename)
      db_needs_init = !File.exist?(filename)

      @db = SQLite3::Database.new(filename)
      @db.results_as_hash = true
      @db.type_translation = true

      # The latest version of ruby-sqlite seems to have a bug, where
      # sometimes the value is actually a fixnum, so the string
      # comparisons don't work.  This isn't the best fix, but it works
      # for now.
      [ "bit",
        "bool",
        "boolean" ].each do |type|
        @db.translator.add_translator( type ) do |t,v|
          v2 = v.to_s
          !( v2.strip.gsub(/00+/,"0") == "0" ||
             v2.downcase == "false" ||
             v2.downcase == "f" ||
             v2.downcase == "no" ||
             v2.downcase == "n" )
        end
      end

      init_database if db_needs_init
    end

    def debug(debug_on = true)
      if debug_on
        @db.trace { |sql| puts sql }
      else
        @db.trace
      end
    end

    # Creates the database tables that this class acts as a facade for
    def init_database()
      @db.execute_batch(<<SQL
create table configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_name TEXT NOT NULL UNIQUE,
    show_name TEXT NOT NULL,
    rss_filename TEXT NOT NULL,
    rss_link TEXT NOT NULL,
    rss_baseurl TEXT NOT NULL,
    rss_ownername TEXT NOT NULL,
    rss_owneremail TEXT NOT NULL,
    ep_to_keep INTEGER NOT NULL DEFAULT 5,
    encode_crop TEXT,
    encode_audio_bitrate INTEGER,
    encode_video_bitrate INTEGER,
    encode_decomb INTEGER,
    max_width INTEGER,
    max_height INTEGER,
    aggregate BOOLEAN
);
create index configs_config_name_index on configs(config_name);
create table shows (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    configid TEXT NOT NULL,
    s_name TEXT,
    s_ep_title TEXT,
    s_ep_number TEXT,
    s_ep_description TEXT,
    s_ep_length INTEGER,
    s_ep_timecap INTEGER,
    s_ep_programid TEXT NOT NULL,
    filename TEXT UNIQUE,
    FOREIGN KEY(configid) REFERENCES configs(id)
);
create index shows_programid_index on shows(s_ep_programid);
create index shows_configid_index on shows(configid);
SQL
                        )
    end

    # Gets the configs from the config table, by default it will get all unless
    # an array of names is passed in.
    def get_configs(names=nil)
      result = Array.new
      if names.nil? || names.empty?
        @db.query("select * from configs") { |rs| rs.each { |r| result << r } }
      else
        qms = Array.new(names.size, '?').join(',')
        @db.query("select * from configs where config_name in (#{qms})",
                  names) do |rs|
          rs.each { |r| result << r }
        end
      end
      return result
    end

    def add_config(kvpairs)
      ps = @db.prepare('insert into configs(config_name, show_name, rss_filename,
                      rss_link, rss_baseurl, rss_ownername, rss_owneremail,
                      ep_to_keep, encode_crop, encode_audio_bitrate,
                      encode_video_bitrate, max_width, encode_decomb, aggregate)
                      values (:config_name, :show_name, :rss_filename,
                      :rss_link, :rss_baseurl, :rss_ownername, :rss_owneremail,
                      :ep_to_keep, :encode_crop, :encode_audio_bitrate,
                      :encode_video_bitrate, :max_width, :encode_decomb,
                      :aggregate)')
      ps.bind_params(kvpairs)
      pp ps
      puts ps.to_s
      ps.execute()
      ps.close()
    end

    # Gets the configs from the config table based on the Array of
    # config ids passed in.
    def get_configs_by_ids(configs)
      result = Array.new
      qms = Array.new(configs.size, '?').join(',')
      @db.query("select * from configs where id in (#{qms})", configs) do |rs|
        rs.each { |r| result << r }
      end
      return result
    end

    # Select all the shows for a given config id
    def shows_by_configid(id, &block)
      @db.query("select * from shows where configid=?", id) do |rows|
        rows.each { |row| yield row }
      end
    end

    # Select all shows for the aggregated feed
    def get_aggregate_shows(&block)
      @db.query("select * from shows where configid in (select id from configs where aggregate=1) order by id") do |rows|
        rows.each { |row| yield row }
      end
    end

    # Returns the filenames for everything in the show table and their
    # associated ids and configids...
    def get_filenames(&block)
      @db.query("select id,configid,filename from shows") do |rows|
        rows.each { |row| yield row }
      end
    end

    # Add a show to the database for a given config and video stored
    # in the given filename
    def add_show(show, config, filename)
      ps = @db.prepare('insert into shows(configid, s_name, s_ep_title, s_ep_number, s_ep_description, s_ep_length, s_ep_timecap, s_ep_programid, filename) values (?, ?, ?, ?, ?, ?, ?, ?, ?);')
      ps.execute(config['id'], show.title, show.episode_title(true),
             show.episode_number, show.description, show.duration,
             show.time_captured.to_i, show.program_id, filename)
      ps.close()
    end

    # Cleans up shows that go over the keep threshold specified in the config
    def old_show_cleanup(config)
      filenames = Array.new\
      @db.execute('create temp table cleanup_temp as select id,filename from shows where configid=? order by s_ep_timecap desc;', config['id'])
      @db.query('select id,filename from cleanup_temp where rowid>?',
                config['ep_to_keep']) do |results|
        results.each do |r|
          filenames << r['filename']
          @db.execute('delete from shows where id=?;', r['id'])
        end
      end
      # Yes, its only in memory, but we may be called many times in here.
      @db.execute('drop table cleanup_temp;')
      return filenames
    end

    def delete_shows(shows)
      qms = Array.new(shows.size, '?').join(',')
      @db.execute("delete from shows where id in (#{qms})", shows)
    end

    # Reports if a show is in the database by looking to see if
    # program_id is in the database.
    def got_show?(config, show)
      got_one = false
      # There is probably a better way to test for existance, but I'll
      # ask for help later
      @db.query('select 1 from shows where configid=? and s_ep_programid=?',
                config['id'], show.program_id) do |results|
        results.each do |rs|
          got_one = true
        end
      end
      return got_one
    end
  end
end


# Local Variables:
# mode: ruby
# End:
