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
require 'tivopodcast/database'
require 'tivopodcast/rss_generator'

module Tivo2Podcast
  class FileCleaner
    def self.file_cleanup
      # I'm not wild about this, but loading the filenames first
      # limits doing multiple calls to the database.  Since we only
      # generated .m4v files now, this seems safe, but we might want
      # to revisit it.
      files = Dir['*.m4v']
      deleted_shows = Tivo2Podcast::Show.preload(:config).on_disk.where.not(filename: files)

      deleted_shows.map(&:filename).each { |f| puts "#{f} missing, removing from database." }
      deleted_shows.update_all(on_disk: false)

      configs = deleted_shows.map(&:config).uniq
      Tivo2Podcast::RssGenerator.generate_from_configs(configs) unless configs.empty?
    end
  end
end
