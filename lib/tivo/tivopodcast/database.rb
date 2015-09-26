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

require 'active_record'

module Tivo2Podcast
  def self.connect_database(filename)
    database_exists = File.exist?(filename)

    ActiveRecord::Base.establish_connection(adapter: 'sqlite3',
                                            database: filename)

    unless database_exists
      # $log.debug { "Creating database schema" }
      # ActiveRecord::Migration.verbose = false
      AddConfig.new.up
      AddShow.new.up
    end
  end

  module Db
    class AddConfig < ActiveRecord::Migration
      def up
        create_table :configs do |t|
          t.string :config_name, null: false
          t.string :show_name, null: false
          t.string :rss_filename, null: false
          t.string :rss_link, null: false
          t.string :rss_baseurl, null: false
          t.string :rss_ownername, null: false
          t.string :rss_owneremail, null: false
          t.integer :ep_to_keep, null: false, default: 5
          t.string :encode_crop
          t.integer :encode_audio_bitrate
          t.integer :encode_video_bitrate
          t.integer :video_decomb
          t.integer :max_width
          t.integer :max_height
          t.boolean :aggregate
        end
        add_index :configs, :config_name, unique: true
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end

    class AddShows < ActiveRecord::Migration
      def up
        create_table :shows do |t|
          # TODO: Need to add configid and specify a forgein key to it
          t.integer :configid, null: false
          t.string :s_name
          t.string :s_ep_title
          t.string :s_ep_number
          t.string :s_ep_description
          t.integer :s_ep_length
          t.integer :s_ep_timecape
          t.string :s_ep_programid
          t.string :filename
          t.boolean :on_disk, null: false
          # add execute for foreign key enforcement by db?
          # FOREIGN KEY(configid) REFERENCES configs(id)
        end
        add_index :shows, :configid
        add_index :shows, :s_ep_programid
        add_index :shows, :filename, unique: true
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end

    class Config < ActiveRecord::Base
      # The has_and_belogs_to_many expects a configs_rss_files table.
      has_and_belongs_to_many :rss_files
      has_many :shows, foreign_key: 'configid'
    end

    class Show < ActiveRecord::Base
      belongs_to :config, foreign_key: 'configid'
      has_many :rss_files, through: :config
      validates_presence_of :config

      def self.new_from_config_show_filename(config, showinfo, filename)
        show = Show.new
        show.config = config

        show.s_name = showinfo.title
        show.s_ep_title = showinfo.episode_title(true)
        show.s_ep_number = showinfo.episode_number
        show.s_ep_description = showinfo.description
        show.s_ep_length = showinfo.duration
        show.s_ep_timecap = showinfo.time_captured.to_i
        show.s_ep_programid = showinfo.program_id
        show.on_disk = true

        show.filename = filename

        show
      end
    end

    class RssFile < ActiveRecord::Base
      # The has_and_belogs_to_many expects a configs_rss_files table.
      has_and_belongs_to_many :configs
    end
  end
end
