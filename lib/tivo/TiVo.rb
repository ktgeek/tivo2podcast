# Copyright 2010 Keith T. Garner. All rights reserved.
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
require 'rexml/document'
require 'httpclient'

module TiVo
  FOLDER = 'x-tivo-container/folder'
  VIDEO = 'video/x-tivo-raw-tts'

  class TiVoListings
    attr_accessor :folders, :videos

    def initialize(folders = nil, videos = nil)
      @folders = folders.nil? ? Array.new : folders
      @videos = videos.nil? ? Array.new : videos
    end

    def total_size
      @folders.size + @videos.size
    end

    # We expect another TiVoListings to be passed in here.
    def concat(tl)
      @folders.concat(tl.folders)
      @videos.concat(tl.videos)
    end
  end

  # Will return the first TiVo found via
  # DNSSD/ZeroConf/Bounjour/whatever or nil unless a name for the TiVo is
  # given then it will return the TiVo that matches that name or nil.
  #
  # This assumes the host system has everything configure properly to
  # work for DNSSD, it also assumes your TiVos are assigned different
  # names.
  def TiVo.locate_via_dnssd(name = nil, sleep_time = 5)
    tivos = tivos_via_dnssd(sleep_time)
    tivos.nil? ? nil : tivos[name]
  end

  # Returns a Hash that maps tivo name to tivo ip
  def TiVo.tivos_via_dnssd(sleep_time = 5, reaquire=false)
    if @@tivos.nil? || reaquire
      # We'll only load these classes if we're actually called.
      require 'socket'
      require 'dnssd'

      replies = []
      service = DNSSD.browse '_tivo-videos._tcp' do |b|
        DNSSD.resolve(b) do |r|
          replies << r
        end
      end
      sleep(sleep_time)

      return nil if replies.size < 1

      service.stop

      @@tivos = Hash[replies.collect { |x| [x.name,
                                            IPSocket.getaddress(x.target)] }]
    end

    @@tivos
  end

  class TiVoItemFactory
    def TiVoItemFactory.from_xml(xml)
      document = REXML::Document.new(xml)

      videos = Array.new
      folders = Array.new

      document.root.elements.each('Item') do |element|
        if element.elements['Details'].elements['ContentType'].text == FOLDER
          folders << TiVoFolder.new(element)
        else
          videos << TiVoVideo.new(element)
        end
      end

      TiVoListings.new(folders, videos)
    end
  end

  class TiVoItem
    def initialize(element)
      @xml_element = element
      @details = element.elements['Details']
      @links = element.elements['Links']
    end

    def title
      get_detail_item('Title')
    end

    def printable_title
      self.title
    end

    def url
      @links.elements['Content'].elements['Url'].text
    end

    def get_detail_item(name)
      name = @details.elements[name]
      name.text unless name.nil?
    end

    def is_folder?
      get_detail_item('ContentType') == FOLDER
    end

    protected :get_detail_item
  end

  class TiVoFolder < TiVoItem
    def item_count
      get_detail_item('TotalItems').to_i
    end
  end

  class TiVoVideo < TiVoItem
    def printable_title
      result = self.title
      ep = self.episode_title
      result = "#{result}: #{ep}" unless ep.nil?
      result
    end

    def episode_title(use_date_if_nil=false)
      title = get_detail_item('EpisodeTitle')
      if use_date_if_nil && title.nil?
        title = time_captured.strftime("%m/%d/%Y")
      end
      title
    end

    def episode_number
      get_detail_item('EpisodeNumber')
    end

    def description
      desc = get_detail_item('Description')
      unless desc.nil?
        desc.sub!(' Copyright Tribune Media Services, Inc.', '')
      end
      desc
    end

    def channel
      get_detail_item('SourceChannel').to_i
    end

    def station
      get_detail_item('SourceStation')
    end

    def time_captured
      Time.at(get_detail_item('CaptureDate').to_i(16) + 2)
    end

    def program_id
      get_detail_item('ProgramId')
    end

    def series_id
      get_detail_item('SeriesId')
    end

    def size
      get_detail_item('SourceSize').to_i
    end

    # Helper method that class TiVoVideo.human_duration on the local object
    def human_duration
      TiVoVideo.human_duration(duration)
    end

    # Giving a duration in milliseconds, return the duration of a
    # program as a string in HH:MM:SS or MM:SS formats, which
    # coincidently, will also make RSS Maker's itunes duration happy.
    def TiVoVideo.human_duration(dur)
      # Duration is in milliseconds, and we don't need that percision,
      # so lets just lop it off.  This leaves us with seconds.
      seconds = dur / 1000

      # Calculate the hours by dividing by 3600
      hours = seconds / 3600

      # Calculate the minutes by dividing by 60 of the remainder after hours.
      seconds = seconds % 3600
      minutes = seconds / 60

      # Calculate the left over unsloppy seconds
      seconds = seconds % 60

      result = StringIO.new
      result.printf("%d:", hours) if hours > 0
      result.printf("%02d:%02d", minutes, seconds)
      result.string
    end

    def duration
      get_detail_item('Duration').to_i
    end

    def copy_protected?
      result = false
      cp = get_detail_item('CopyProtected')
      result = cp.downcase == "yes" unless cp.nil?
      result
    end
  end

  class TiVo
    USER = 'tivo'

    def initialize(ip, mak)
      @ip = ip
      @mak = mak
      @base_url = 'https://' + ip + '/TiVoConnect'
      @client = HTTPClient.new
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @client.set_auth(@base_url, USER, @mak)
    end

    # Constant for the internal batch size around get_listings
    BATCH_SIZE = 50
    def get_listings(recurse=true, get_xml=false)
      query_url = @base_url +
        "?Command=QueryContainer&Container=/NowPlaying&ItemCount=#{BATCH_SIZE}"
      if recurse
        query_url += '&Recurse=Yes'
      end

      listings = nil

      if get_xml
        listings = get_listings_xml(query_url)
      else
        listings = TiVoListings.new
        offset = 0

        loop do
          url = query_url + "&AnchorOffset=#{offset}"
          new_listings = get_listings_from_url(url)
          listings.concat(new_listings)
          break if new_listings.total_size < BATCH_SIZE
          offset += BATCH_SIZE
        end
      end
      listings
    end

    def get_listings_from_url(url, recurse=false)
      # This needs to be expanded to loop around if all the videos
      # weren't snagged in the first grab.  We'll need to make some
      # URL assumptions we hadn't before.
      xml = @client.get_content(url)
      listings = TiVoItemFactory.from_xml(xml)
      if recurse
        listings.folders.each do |f|
          new_listings = get_listings_from_url(f.url)
          listings.videos.concat(new_listings) unless new_listings.nil?
        end
        listings.folders = nil
      end
      listings
    end

    # Returns the raw XML for listings.  This is really useful for
    # debugging and learning new fields from the TiVo.  Not really
    # expected to be used by end user programs
    def get_listings_xml(url)
      @client.get_content(url)
    end

    # Returns all show matching the given name/regex that are not copy
    # protected and is sorted by the time captured.
    def get_shows_by_name(showname)
      get_listings.videos.select { |s| s.title =~ /#{showname}/ &&
        !s.copy_protected? }.sort_by { |s| s.time_captured }
    end

    # Downloads the show given the item passed in.  If a block is given,
    # it uses the block instead of the filename
    def download_show(tivo_item, filename=nil, &block)
      if block.nil? && filename.nil?
        raise ArgumentError, 'Must have either a filename or a block', caller
      end
      file = File.open(filename, 'wb') unless filename.nil?
      begin
        url = tivo_item.url
        @client.set_auth(url, USER, @mak)
        @client.get_content(url, nil, {'Connection' => 'close'}) do |c|
          if block
            block.call(c)
          else
            file << c
          end
        end
      rescue HTTPClient::BadResponseError => e
        raise TiVoDownloadError, "Error downloading from TiVo", caller
      ensure
        file.close unless file.nil?
      end
    end

    private :get_listings_from_url
  end

  class TiVoDownloadError < IOError
  end
end
