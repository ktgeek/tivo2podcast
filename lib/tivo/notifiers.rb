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
        # TODO: I should check to see if the require was successful.
        #       If not, I should probably toss an exception.

        # This require makes the assumption that if __FILE__ is in the
        # path, We can naturally look down one level.
        require "notifiers/#{n + '_notifier'}"
        @notifiers << Kernel.const_get("TiVo2Podcast").const_get(n.capitalize + "Notifier").new(@config)
      end
    end

    def notify(message)
      @notifiers.each { |n| n.notify(message) }
    end
  end
end

