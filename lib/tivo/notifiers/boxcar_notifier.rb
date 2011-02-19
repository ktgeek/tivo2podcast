#require 'Notifier'
require 'rubygems'
require 'boxcar_api'

module TiVo2Podcast
  class BoxcarNotifier
    def initialize(config)
      @config = config
      @boxcar = BoxcarAPI::User.new(@config["boxcar.user"], @config["boxcar.password"])
    end

    def notify(message)
      @boxcar.notify(message, 'TiVo2Podcast')
    end
  end
end
