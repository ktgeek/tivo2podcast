#require 'Notifier'
require 'rubygems'
require 'boxcar_api'

module TiVo
  class BoxcarNotifier
    def initialize(config)
      @config = config
      @boxcar = BoxcarAPI::User.new(@config.notifier["boxcar.user"],
                                    @config.notifier["boxcar.password"])
    end

    def notify(message)
      ba.notify(message, 'TiVo2Podcast')
    end
  end
end
