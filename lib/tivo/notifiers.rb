# Base notifier class, has all the common methods

module TiVo2Podcast
  class Notifier
    def initialize(config)
      @config = config
      @notifiers = Array.new
      init_notifiers
    end

    def init_notifiers
      @config["notifiers"].each do |n|
        require "notifiers/#{n + '_notifier'}"
        @notifiers << Kernel.const_get("TiVo2Podcast").const_get(n.capitalize + "Notifier").new(@config)
      end
    end

    def notify_all(message)
      @notifiers.each { |n| n.notify(message) }
    end
  end
end

