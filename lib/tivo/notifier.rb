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
        # This require makes the assumption that if __FILE__ is in the
        # path, We can naturally look down one level.
        begin
          require "notifiers/#{n + '_notifier'}"
          @notifiers << Kernel.const_get("TiVo2Podcast").const_get(n.capitalize + "Notifier").new(@config)
        rescue LoadError
          # Should this toss an exception instead of an error message?
          puts "Could not find #{n} notifier... Ignoring."
        end
      end
    end

    def notify(message)
      @notifiers.each { |n| n.notify(message) }
    end
  end
end

