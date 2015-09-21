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
require 'singleton'

module Tivo2Podcast
  class NotifierEngine
    include Singleton

    def initialize
      @notifiers = Array.new
      init_notifiers
    end

    def init_notifiers
      Tivo2Podcast::Config.instance["notifiers"].each do |n|
        # This require makes the assumption that if __FILE__ is in the
        # path, We can naturally look down one level.
        begin
          require "tivopodcast/notifiers/#{n}_notifier}"
          @notifiers = Notifier.registered_notifiers.map { |n| n.new }
        rescue LoadError
          # Should this toss an exception instead of an error message?
          puts "Could not find #{n}_notifier notifier... Ignoring."
        end
      end
    end

    def notify(message)
      @notifiers.each { |n| n.notify(message) }
    end

    def shutdown
      @notifiers.each { |n| n.shutdown }
    end
  end

  # Base class for doing notifications. Will respond to notify and shutdown, but
  # will do nothing.  Also handles registration of notifiers
  class Notifier
    @@registered_notifiers = Array.new

    def self.inherited(subclass)
      @@registered_notifiers << subclass
    end

    def notify(message)
    end

    def shutdown
    end
  end
end

