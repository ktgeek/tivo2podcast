# Base notifier class, has all the common methods

module TiVo
  class Notifier
    def initalize(config)
      @config = config
      @notifiers = Array.new
      init_notifiers
    end

    def init_notifiers
      config.notifiers.each do |n|
        require "notifiers/#{n}"
        @notifiers << Kernel.const_get("TiVo").const_get(n).new(@config)
      end
    end
  end
end

