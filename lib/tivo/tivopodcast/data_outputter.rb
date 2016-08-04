require 'tivopodcast/database'

module Tivo2Podcast
  class DataOutputter
    def initialize(io_handle = $stdout)
      @io_handle = io_handle
    end

    CONFIG_FORMAT = "%-20.16s%-50.50s\n"
    def configs
      config_name = "Config name"
      show_name = "Show name"
      @io_handle.printf(CONFIG_FORMAT, "Config name", "Show name")
      @io_handle.printf(CONFIG_FORMAT, '-' * config_name.size, '-' * show_name.size)
      Tivo2Podcast::Config.select(:id, :config_name, :show_name).find_each do |config|
        @io_handle.printf(CONFIG_FORMAT, config.config_name, config.show_name)
      end
    end
  end
end
