require 'tivopodcast/database'
require 'tty-table'

module Tivo2Podcast
  class DataOutputter
    def initialize(io_handle = $stdout)
      @io_handle = io_handle
    end

    HEADERS = ['id', 'Config name', 'Show name'].freeze

    CONFIG_FORMAT = "%-20.16s%-50.50s\n"
    def configs
      table = TTY::Table.new(header: HEADERS) do |t|
        Tivo2Podcast::Config.select(:id, :config_name, :show_name).find_each do |config|
          t << [config.id, config.config_name, config.show_name]
        end
      end

      @io_handle.puts table.render(:unicode, resize: true, padding: [0, 1, 0, 1], width: 80, column_widths: [6, 10, 10])
    end
  end
end
