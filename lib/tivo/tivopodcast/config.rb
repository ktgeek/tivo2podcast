# -*- coding: utf-8 -*-
# Copyright 2016 Keith T. Garner. All rights reserved.
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
#
require 'forwardable'
require 'singleton'
require 'yaml'
require 'TiVo'

module Tivo2Podcast
  # This class makes up the configuation for the TiVo2Podcast engine
  # and includes factory and convenience methods
  class Config
    include Singleton
    extend Forwardable

    CONFIG_DIRECTORY = if ENV['TIVO2PODCASTDIR'].nil?
                         ENV['HOME']
                       else
                         ENV['TIVO2PODCASTDIR']
                       end

    # The default configuration filename
    CONFIG_FILENAME = File.join(CONFIG_DIRECTORY, ".tivo2podcast.conf")
    DATABASE_FILENAME = File.join(CONFIG_DIRECTORY, ".tivo2podcast.db")

    # Inialize the configuration with an optional file to pull the
    # base config from.
    def initialize
      @config = {
        tivo_addr: nil,
        tivo_name: nil,
        mak: nil,
        verbose: false,
        opt_config_names: Array.new,
        tivodecode: 'tivodecode',
        handbrake: 'HandBrakeCLI',
        cleanup: false,
        atomicparsley: 'AtomicParsley',
        comskip: nil,
        comskip_ini: nil,
        baseurl: nil,
        aggregate_file: nil,
        notifiers: Array.new,
        regenerate_rss: false,
        console: false
      }

      load_from_file(CONFIG_FILENAME)
    end

    def load_from_file(config_file)
      @config.merge!(YAML.load_file(config_file)) if File.exist?(config_file)
    end

    # Creates an instance of a TiVo object based on the configurations
    # tivo_addr and mak
    def tivo_factory
      TiVo::TiVo.new(tivo_addr, mak)
    end

    def tivo_addr=(value)
      @config[:tivo_addr] = value
    end

    # Returns the tivo_address defined in the config.  If one is not
    # defined in the config, try to locate the tivo vi dnssd
    def tivo_addr
      if @config[:tivo_addr].nil?
        puts "Attemping to locate tivo #{@config['tivo_name'] unless @config['tivo_name'].nil?}..." if @config['verbose']
        tmp = TiVo.locate_via_dnssd(@config[:tivo_name])
        if tmp.nil?
          puts "TiVo not found!" if @config[:verbose]
          # Should be changed to an exception to be throw
          printf($stderr, "TiVo hostname or IP required to run the script\n")
          exit(1)
        else
          puts "TiVo found at #{tmp}" if @config['verbose']
          @config[:tivo_addr] = tmp
        end
      end

      result = @config[:tivo_addr]
      # If the tivo_addr is NOT a dotted quad, do a DNS lookup for the
      # IP. The TiVo wants us to pass the IP address for whatever reason.
      if /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(result).nil?
        result = IPSocket.getaddress(result)
      end
      result
    end

    def tivo_name=(value)
      @config[:tivo_name] = value
    end

    def mak=(value)
      @config[:mak] = value
    end

    # Returns the mak from the configuration file or look it up via
    # the .tivodecode_make file
    def mak
      if @config[:mak].nil?
        # Load the mak if we have a mak file
        mak_file = "#{ENV['HOME']}#{File::SEPARATOR}.tivodecode_mak"
        @config[:mak] = File.read(mak_file).strip if File.exist?(mak_file)
      end
      @config[:mak]
    end

    def verbose=(value)
      @config[:verbose] = value
    end

    def cleanup=(value)
      @config[:cleanup] = value
    end

    def regenerate_rss=(value)
      @config[:regenerate_rss] = value
    end

    def console=(value)
      @config[:console] = value
    end

    # For backward compatibility with Config from when more things
    # were attainable by methods, we'll check the configuration hash
    # first for an entry with the same name as the method being
    # called.  If there's nothing in the hash, we'll call the normal
    # method_missing to throw the exception.
    def method_missing(method, *params)
      value = @config[method.to_sym]
      return value unless value.nil?
      super
    end

    def_delegator :@config, :[]
  end
end

# Local Variables:
# mode: ruby
# End:
