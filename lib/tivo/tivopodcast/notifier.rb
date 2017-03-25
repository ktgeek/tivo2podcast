# Copyright 2015 Keith T. Garner. All rights reserved.
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
require 'singleton'

module Tivo2Podcast
  class NotifierEngine
    include Singleton

    def initialize
      @notifiers = Array.new
      init_notifiers
    end

    def init_notifiers
      Tivo2Podcast::AppConfig.instance["notifiers"]&.each do |n|
        begin
          require "tivopodcast/notifiers/#{n}_notifier"
        rescue LoadError
          # Should this toss an exception instead of an error message?
          puts "Could not find #{n}_notifier... Ignoring."
        end
      end
      @notifiers = Notifier.registered_notifiers.map(&:new)
    end

    def self.notify(message)
      instance.notify(message)
    end

    def notify(message)
      @notifiers.each { |n| n.notify(message) }
    end

    def shutdown
      @notifiers.each(&:shutdown)
    end
  end

  # Base class for doing notifications. Will respond to notify and
  # shutdown, but will do nothing.  Also handles registration of
  # notifiers
  class Notifier
    def self.inherited(subclass)
      self.registered_notifiers << subclass
    end

    def self.registered_notifiers
      @registered_notifiers ||= []
    end

    def notify(_message)
    end

    def shutdown
    end
  end
end
