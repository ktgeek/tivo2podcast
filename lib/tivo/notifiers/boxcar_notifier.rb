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
#require 'Notifier'
require 'rubygems'
require 'boxcar_api'

module TiVo2Podcast
  class BoxcarNotifier
    def initialize(config)
      @config = config
      user, password = @config["boxcar.user"], @config["boxcar.password"]
      puts "about to talk about user and password"
      if user.nil? || password.nil?
        raise ArgumentError, 'Both boxcar.user and boxcar.password must be defined for the Boxcar notifier'
      else
        @boxcar = BoxcarAPI::User.new(@config["boxcar.user"], @config["boxcar.password"])
      end
    end

    def notify(message)
      # TODO: I should check for failure here (based on the result of
      #       a call) and then disable doing the notify
      @boxcar.notify(message, 'TiVo2Podcast') unless @boxcar.nil?
    end
  end
end
