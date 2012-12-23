# -*- coding: utf-8 -*-
# Copyright 2012 Keith T. Garner. All rights reserved.
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

require 'active_record'

module Tivo2Podcast
  def Tivo2Podcast.connect_database(filename)
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',
                                            :database  => filename)
  end
  
    # Creates the database tables that this class acts as a facade for
#     def init_database()
#       @db.execute_batch(<<SQL
# create table configs (
#     id INTEGER PRIMARY KEY AUTOINCREMENT,
#     config_name TEXT NOT NULL UNIQUE,
#     show_name TEXT NOT NULL,
#     rss_filename TEXT NOT NULL,
#     rss_link TEXT NOT NULL,
#     rss_baseurl TEXT NOT NULL,
#     rss_ownername TEXT NOT NULL,
#     rss_owneremail TEXT NOT NULL,
#     ep_to_keep INTEGER NOT NULL DEFAULT 5,
#     encode_crop TEXT,
#     encode_audio_bitrate INTEGER,
#     encode_video_bitrate INTEGER,
#     encode_decomb INTEGER,
#     max_width INTEGER,
#     max_height INTEGER,
#     aggregate BOOLEAN
# );
# create index configs_config_name_index on configs(config_name);
# create table shows (
#     id INTEGER PRIMARY KEY AUTOINCREMENT,
#     configid TEXT NOT NULL,
#     s_name TEXT,
#     s_ep_title TEXT,
#     s_ep_number TEXT,
#     s_ep_description TEXT,
#     s_ep_length INTEGER,
#     s_ep_timecap INTEGER,
#     s_ep_programid TEXT NOT NULL,
#     filename TEXT UNIQUE,
#     FOREIGN KEY(configid) REFERENCES configs(id)
# );
# create index shows_programid_index on shows(s_ep_programid);
# create index shows_configid_index on shows(configid);
# SQL
#                         )
#     end

  module Db
    class Config < ActiveRecord::Base
      has_many :shows, :foreign_key => 'configid'
    end

    class Show < ActiveRecord::Base
      belongs_to :config, :foreign_key => 'configid'
    end
  end
end
