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

require 'active_record'

module Tivo2Podcast
  def Tivo2Podcast.connect_database(filename)
    database_exists = File.exists?(filename)
    
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',
                                            :database  => filename)

    unless database_exists
      # $log.debug { "Creating database schema" }
#      ActiveRecord::Migration.verbose = false
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
          t.integer :ep_to_keep, null: false, default: 5
          t.string :handbreak_preset
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
          #add execute for foreign key enforcement by db?
          #FOREIGN KEY(configid) REFERENCES configs(id)
        end
        add_index :shows, :configid
        add_index :shows, :s_ep_programid
        add_index :shows, :filename, unique: true
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end

    class AddRssFiles < ActiveRecord::Migration
      def up
        create_table :rss_files do |t|
          t.string :filename, null: false
          t.string :owner_name
          t.string :owner_email
          t.string :base_url
          t.string :link
          t.string :feed_title
          t.string :feed_description
        end
        add_index :rss_files, :filename, unique: true

        # TODO: Revisit this to find a way to have it not create a unique id
        create_table :configs_rss_files do |t|
          t.integer :config_id, null: false
          t.integer :rss_file_id, null: false
          # TODO: need to add this restriction that exists in SQLITE.
          #foreign key(config_id) references configs(id) ON DELETE RESTRICT,
          #foreign key(rss_file_id) references rss_files(id) ON DELETE RESTRICT
        end
        add_index :configs_rss_files, :config_id
        add_index :configs_rss_files, :rss_file_id
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end
        
    class Config < ActiveRecord::Base
      # The has_and_belogs_to_many expects a configs_rss_files table.
      has_and_belongs_to_many :rss_files
      has_many :shows, :foreign_key => 'configid'
    end

    class Show < ActiveRecord::Base
      belongs_to :config, :foreign_key => 'configid'
      has_many :rss_files, :through => :config
      validates_presence_of :config

      def Show.new_from_config_show_filename(config, showinfo, filename)
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
          
        return show
      end
    end

    class RssFile < ActiveRecord::Base
      # The has_and_belogs_to_many expects a configs_rss_files table.
      has_and_belongs_to_many :configs
    end
  end
end
