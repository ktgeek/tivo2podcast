# Copyright 2014 Keith T. Garner. All rights reserved.
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

require 'rest_client'

module Tivo2Podcast
  class Boxcar2Notifier < Notifier
    BOXCAR2_API_URL = 'https://new.boxcar.io/api/notifications'

    def initialize
      super

      @token = Tivo2Podcast::Config.instance['boxcar2.token']
      raise ArgumentError, 'boxcar2.token must be defined for the Boxcar notifier' if @token.nil?

      @boxcar2 = RestClient::Resource.new BOXCAR2_API_URL, :ssl_version => 'SSLv23'
      @message_queue = Queue.new
      @transmit_thread = create_transmit_thread
    end

    def notify(message)
      @message_queue.enq message
    end

    def shutdown
      while !@message_queue.empty?
        sleep 2
      end

      @transmit_thread.exit
    end

    def create_transmit_thread
      unless @token.nil?
        Thread.new do
          loop do
            message = @message_queue.deq
            begin
              @boxcar2.post 'user_credentials' => @token,
              'notification[title]' => "Tivo2Podcast: #{message}",
              'notification[long_message]' => message,
              'notification[source_name]' => 'Tivo2Podcast'
            rescue Exception => e
              # TODO: replace this with some form of logging. For now, stderr
              $stderr.puts "Error sending message to boxcar api"
            end
          end
        end
      end
    end
  end
end
