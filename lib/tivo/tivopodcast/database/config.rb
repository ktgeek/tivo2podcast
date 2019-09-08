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
  class Config < ActiveRecord::Base
    # The has_and_belogs_to_many expects a configs_rss_files table.
    has_and_belongs_to_many :rss_files
    has_many :shows

    scope :for_name, ->(name) { where(name: name) }
  end

  module Db
    class AddConfigs < ActiveRecord::Migration[5.2]
      def up
        create_table :configs do |t|
          t.string :name, null: false
          t.string :show_name, null: false
          t.integer :episodes_to_keep, null: false, default: 5
          t.string :handbrake_config
          t.string :tivo
        end
        add_index :configs, :name, unique: true
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end
  end
end
