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
require 'tty-spinner'
require 'pastel'

module Tivo2Podcast
  # This class makes up the configuation for the TiVo2Podcast engine
  # and includes factory and convenience methods
  class AppConfig
    include Singleton
    extend Forwardable

    CONFIG_DIRECTORY = ENV['TIVO2PODCASTDIR'] || ENV['HOME']

    # The default configuration filename
    CONFIG_FILENAME = File.join(CONFIG_DIRECTORY, ".tivo2podcast.conf")
    DATABASE_FILENAME = File.join(CONFIG_DIRECTORY, ".tivo2podcast.db")

    # Inialize the configuration with an optional file to pull the
    # base config from.
    def initialize
      @config = {
        tivo_address: nil,
        mak: nil,
        verbose: false,
        opt_config_names: [],
        handbrake: 'HandBrakeCLI',
        cleanup: false,
        atomicparsley: 'AtomicParsley',
        comskip: nil,
        comskip_ini: nil,
        baseurl: nil,
        aggregate_file: nil,
        notifiers: [],
        regenerate_rss: false,
        console: false,
        tivolibre: nil,
        list_configs: false
      }

      load_from_file(CONFIG_FILENAME)
    end

    def load_from_file(config_file)
      @config.merge!(YAML.load_file(config_file)) if File.exist?(config_file)
    end

    # Creates an instance of a TiVo object based on the configurations
    # tivo_addr and mak.  If tivo_addr is not defined in the config,
    # try to locate the tivo vi dnssd
    def tivo_factory
      require 'TiVo'

      tivo_ip = tivo_address

      unless tivo_ip
        p = proc { tivo_ip = TiVo.locate_via_dnssd }
        verbose? ? locating_tivo_spinner.run(&p) : p.call

        unless tivo_ip
          printf($stderr, "No TiVo found! TiVo hostname or IP required to run the script\n")
          exit(1)
        end

        puts "TiVo found at #{tivo_ip}" if verbose?
        tivo_ip = ensure_ip_address(tivo_ip)
      end

      TiVo::TiVo.new(tivo_ip, mak)
    end

    def tivo_address=(value)
      @config[:tivo_address] = value
    end

    # Returns the tivo_address IP defined in the config
    def tivo_address
      ensure_ip_address(@config[:tivo_address])
    end

    def mak=(value)
      @config[:mak] = value
    end

    # Returns the mak from the configuration file or look it up via
    # the .tivodecode_make file
    def mak
      @config[:mak] ||= begin
        mak_file = File.join(ENV['HOME'], '.tivodecode_mak')
        File.read(mak_file).strip if File.exist?(mak_file)
      end
    end

    def verbose=(value)
      @config[:verbose] = value
    end

    def verbose?
      @config[:verbose]
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

    def list_configs=(value)
      @config[:list_configs] = value
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

    private

    def locating_tivo_spinner
      pastel = Pastel.new
      spin_text = "#{pastel.green(':spinner')} Locating tivo... "
      TTY::Spinner.new(spin_text, format: :dots)
    end

    # if passed in tivo_address is not nil AND its not already a
    # dotted quad, do a lookup.  If tivo_address is nil, this will
    # return nil.
    def ensure_ip_address(tivo_address)
      return IPSocket.getaddress(tivo_address) if tivo_address && !/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match?(result)
      tivo_address
    end
  end
end

# Local Variables:
# mode: ruby
# End:
