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
require 'TiVo'

module Tivo2Podcast
  class Config
    extend Forwardable

    CONFIG_FILENAME = (ENV['TIVO2PODCASTDIR'].nil? ?
                       ENV['HOME'] : ENV['TIVO2PODCASTDIR']) +
      File::SEPARATOR + '.tivo2podcast.conf'

    def initialize(file = nil)
      @config = {
        "tivo_addr" => nil,
        "mak" => nil,
        "verbose" => false,
        "opt_config_names" => Array.new,
        "tivodecode" => 'tivodecode',
        "handbrake" => 'HandBrakeCLI',
        "cleanup" => false,
        "atomicparsley" => 'AtomicParsley',
        "comskip" => nil,
        "comskip_ini" => nil,
        "addchapterinfo" => nil,
        "baseurl" => nil,
        "aggregate_file" => nil,
        "notifiers" => Array.new
      }

      config_file = file.nil? ? CONFIG_FILENAME : file

      if File.exists?(config_file)
        @config.merge!(YAML.load_file(config_file))
      end
    end

    def aggregate?
      !(@config['aggregate_file'].nil? || @config['baseurl'].nil?)
    end

    def aggregate_config
      {
        'show_name' => 'Aggregated',
        'rss_baseurl' => @config['baseurl'],
        'rss_filename' => @config['aggregate_file']
      }
    end
    
    def tivo_factory
      return TiVo::TiVo.new(tivo_addr, mak)
    end

    def tivo_addr=(value)
      @config['tivo_addr'] = value
    end
    
    # Should this throw an exception when the tivo isn't found, or should it
    # Also, should the tivo location be moved up to 
    def tivo_addr
      # If the user didn't pass in a address or hostname via the command line,
      # try to locate it via dnssd.
      if @config['tivo_addr'].nil?
        puts "Attemping to locate tivo..." if @verbose
        tmp = TiVo.locate_via_dnssd
        if tmp.nil?
          puts "TiVo not found!" if @verbose
          # Should be changed to an exception to be throw
          printf($stderr, "TiVo hostname or IP required to run the script\n")
          exit(1)
        else
          puts "TiVo found at #{tmp}" if @verbose
          @tivo_addr = tmp
        end
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

    def mak=(value)
      @config['mak'] = value
    end
    
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

    # For backward compatibility with Config from when more things
    # were attainable by methods, we'll check the configuration hash
    # first an entry with the same name as the method being called.
    # If there's nothing in the hash, we'll call the normal
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
