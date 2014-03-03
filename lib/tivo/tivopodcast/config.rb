# -*- coding: utf-8 -*-
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
#
require 'forwardable'
require 'yaml'
require 'TiVo'

module Tivo2Podcast
  # This class makes up the configuation for the TiVo2Podcast engine
  # and includes factory and convenience methods
  class Config
    extend Forwardable

    # The default configuration filename
    CONFIG_FILENAME = (ENV['TIVO2PODCASTDIR'].nil? ?
                       ENV['HOME'] : ENV['TIVO2PODCASTDIR']) +
      File::SEPARATOR + '.tivo2podcast.conf'

    # Inialize the configuration with an optional file to pull the
    # base config from.
    def initialize(file = nil)
      @config = {
        "tivo_addr" => nil,
        "tivo_name" => nil,
        "mak" => nil,
        "verbose" => false,
        "opt_config_names" => Array.new,
        "tivodecode" => 'tivodecode',
        "handbrake" => 'HandBrakeCLI',
        "cleanup" => false,
        "atomicparsley" => 'AtomicParsley',
        "comskip" => nil,
        "comskip_ini" => nil,
        "baseurl" => nil,
        "aggregate_file" => nil,
        "notifiers" => Array.new,
        "regenerate_rss" => false
      }

      config_file = file.nil? ? CONFIG_FILENAME : file

      if File.exists?(config_file)
        @config.merge!(YAML.load_file(config_file))
      end
    end

    # Creates an instance of a TiVo object based on the configurations
    # tivo_addr and mak
    def tivo_factory
      return TiVo::TiVo.new(tivo_addr, mak)
    end

    def tivo_addr=(value)
      @config['tivo_addr'] = value
    end

    # Returns the tivo_address defined in the config.  If one is not
    # defined in the config, try to locate the tivo vi dnssd
    def tivo_addr
      if @config['tivo_addr'].nil?
        puts "Attemping to locate tivo #{@config['tivo_name'] unless @config['tivo_name'].nil?}..." if @config['verbose']
        tmp = TiVo.locate_via_dnssd(@config['tivo_name'])
        if tmp.nil?
          puts "TiVo not found!" if @config['verbose']
          # Should be changed to an exception to be throw
          printf($stderr, "TiVo hostname or IP required to run the script\n")
          exit(1)
        else
          puts "TiVo found at #{tmp}" if @config['verbose']
          @tivo_addr = tmp
        end
      else
        @tivo_addr = @config['tivo_addr']
      end

      result = @tivo_addr
      # If the tivo_addr is NOT a dotted quad, do a DNS lookup for the
      # IP. The TiVo wants us to pass the IP address for whatever reason.
      # I should use bounjour/ZeroConf to find the local tivo
      if /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(result).nil?
        result = IPSocket.getaddress(@tivo_addr)
      end
      
      return result
    end

    def tivo_name=(value)
      @config['tivo_name'] = value
    end

    def mak=(value)
      @config['mak'] = value
    end

    # Returns the mak from the configuration file or look it up via
    # the .tivodecode_make file
    def mak
      if @config['mak'].nil?
        # Load the mak if we have a mak file
        mak_file = ENV['HOME'] + '/.tivodecode_mak'
        @config['mak'] = File.read(mak_file).strip if File.exist?(mak_file)
      end
      return @config['mak']
    end

    def verbose=(value)
      @config['verbose'] = value
    end

    def cleanup=(value)
      @config['cleanup'] = value
    end

    def regenerate_rss=(value)
      @config['regenerate_rss'] = value
    end

    # For backward compatibility with Config from when more things
    # were attainable by methods, we'll check the configuration hash
    # first for an entry with the same name as the method being
    # called.  If there's nothing in the hash, we'll call the normal
    # method_missing to throw the exception.
    def method_missing(method, *params)
      method_name = method.to_s
      return @config[method_name] if @config.keys.include?(method_name)
      super
    end

    def_delegator :@config, :[]
  end
end


# Local Variables:
# mode: ruby
# End:
