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
require 'rubygems'
require 'boxcar_api'

module TiVo2Podcast
  class BoxcarNotifier < Notifier
    # This is set for the generic provider from boxcar.  This won't
    # allow us to broadcast, which is fine, since we only care about
    # notifying a single user.
    PROVIDER_KEY = 'MH0S7xOFSwVLNvNhTpiC'
    
    def initialize(config)
      super(config)

      @user = @config["boxcar.user"]
      if @user.nil?
        raise ArgumentError, 'Both boxcar.user and boxcar.password must be defined for the Boxcar notifier'
      end

      @boxcar = BoxcarAPI::Provider.new(PROVIDER_KEY)
      # begin
      #   @boxcar.subscribe(@user)
      # rescue Exception => e
      #   # TODO: replace this with some form of logging. For now, stderr
      #   $stderr.puts "Error subscribing to boxcar api"
      #   @boxcar = nil
      # end
    end

    def notify(message)
      # TODO: I should check for failure here (based on the result of
      #       a call) and then disable doing the notify
      unless @boxcar.nil?
        Thread.new do
          begin
            @boxcar.notify(@user, message, {:from_screen_name => "Tivo2Podcast"})
          rescue Exception => e
            # TODO: replace this with some form of logging. For now, stderr
            $stderr.puts "Error sending message to boxcar api"
          end
        end
      end
    end
  end
end
