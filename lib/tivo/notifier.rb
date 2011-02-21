# Copyright 2011 Keith T. Garner. All rights reserved.
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

