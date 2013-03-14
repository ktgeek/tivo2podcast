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
    on_disk BOOLEAN DEFAULT 1,
    FOREIGN KEY(configid) REFERENCES configs(id)
);
create index shows_programid_index on shows(s_ep_programid);
create index shows_configid_index on shows(configid);
SQL
                        )
    end

  end
end


# Local Variables:
# mode: ruby
# End:
