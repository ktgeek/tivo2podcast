# -*- coding: utf-8 -*-
# Copyright 2015 Keith T. Garner. All rights reserved.
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
require 'set'
require 'tivopodcast/database'
require 'tivopodcast/rss_generator'

module Tivo2Podcast
  class FileCleaner
    def FileCleaner.file_cleanup
      configs = Set.new
      deleteids = Array.new

      Tivo2Podcast::Db::Show.where(on_disk: true).each do |result|
        unless File.exists?(result.filename)
          puts "#{result.filename} missing, removing from database."
          configs.add(result.config)
          result.on_disk = false
          result.save!
        end
      end

      unless configs.empty?
        Tivo2Podcast::RssGenerator.generate_from_configs(configs)
      end
    end
  end
end
