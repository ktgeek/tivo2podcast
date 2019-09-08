# frozen_string_literal: true

# Copyright 2017 Keith T. Garner. All rights reserved.
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

module Tivo2Podcast
  class Show < ActiveRecord::Base
    belongs_to :config
    has_many :rss_files, through: :config
    validates_presence_of :config

    scope :on_disk, -> { where(on_disk: true) }
    scope :for_config, ->(config) { where(config_id: config) }
    scope :episode_for, ->(config, program_id) { where(config_id: config, program_id: program_id) }

    def self.create_from_config_show_filename(config, show, filename)
      Show.create(
        config: config,
        name: show.title,
        episode_title: show.episode_title(use_date_if_nil: true),
        episode_number: show.episode_number,
        description: show.description,
        length: show.duration,
        time_captured: show.time_captured.to_i,
        program_id: show.program_id,
        on_disk: true,
        filename: filename
      )
    end
  end

  module Db
    class AddShows < ActiveRecord::Migration[5.2]
      def up
        create_table :shows do |t|
          t.integer :config_id, null: false
          t.string :name
          t.string :episode_title
          t.string :episode_number
          t.string :description
          t.integer :length
          t.integer :time_captured
          t.string :filename
          t.string :program_id
          t.boolean :on_disk, null: false
        end
        add_index :shows, :config_id
        add_index :shows, :program_id
        add_index :shows, :filename, unique: true
        add_foreign_key :shows, :configs, column: :config_id
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end
  end
end
