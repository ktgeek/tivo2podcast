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

require "active_record"
require "tivopodcast/database/config"
require "tivopodcast/database/show"
require "tivopodcast/database/rss_file"

module Tivo2Podcast
  def self.connect_database(filename)
    database_exists = File.exist?(filename)

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: filename)

    return if database_exists

    # $log.debug { "Creating database schema" }
    # ActiveRecord::Migration.verbose = false
    Db::AddConfigs.new.up
    Db::AddShows.new.up
    Db::AddRssFiles.new.up
    Db::AddConfigsRssFiles.new.up
  end
end
