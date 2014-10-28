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
          require "tivopodcast/notifiers/#{n + '_notifier'}"
          @notifiers << Kernel.const_get("Tivo2Podcast").const_get(n.capitalize + "Notifier").new
        rescue LoadError
          # Should this toss an exception instead of an error message?
          puts "Could not find #{n.capitalize + "Notifier"} notifier... Ignoring."
        end
      end
    end

    def notify(message)
      @notifiers.each { |n| n.notify(message) }
    end
  end

  # Base class for doing notifications. Will respond to notify, but
  # will do nothing.
  class Notifier
    def notify(message)
    end
  end
end

