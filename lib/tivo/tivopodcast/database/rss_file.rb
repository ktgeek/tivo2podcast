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
  class RssFile < ActiveRecord::Base
    # The has_and_belogs_to_many expects a configs_rss_files table.
    has_and_belongs_to_many :configs
  end

  module Db
    class AddRssFiles < ActiveRecord::Migration[5.2]
      def up
        create_table :rss_files do |t|
          t.string :filename, unique: true, null: false
          t.string :owner_name
          t.string :owner_email
          t.string :base_url
          t.string :link
          t.string :feed_title
          t.string :feed_description
        end
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end

    class AddConfigsRssFiles < ActiveRecord::Migration[5.2]
      def up
        create_table :configs_rss_files, id: false do |t|
          t.integer :config_id, null: false
          t.integer :rss_files_id, null: false
        end
        add_foreign_key(:configs_rss_files, :configs)
        add_foreign_key(:configs_rss_files, :rss_files)
      end

      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end
  end
end
