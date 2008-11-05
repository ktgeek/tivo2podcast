require 'rexml/document'
require 'ktghttpclient'

module TiVo
  FOLDER = 'x-tivo-container/folder'
  VIDEO = 'video/x-tivo-raw-tts'

  TivoListings = Struct.new(:folders, :videos)

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
      
      TivoListings.new(folders=folders, videos=videos)
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
      result = result + ": " + ep unless ep.nil?
      return result
    end

    def episode_title
      get_detail_item('EpisodeTitle')
    end

    def episode_number
      get_detail_item('EpisodeNumber')
    end

    def description
      get_detail_item('Description')
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

    def duration
      duration = get_detail_item('Duration').to_i
      hours = duration / (60 * 60 * 1000)
      minutes = (((duration % (60 * 60 * 1000)) / (60.0 * 1000)) + 0.5).to_i
      # Rounding can get us a situation where things are 0 hours and 60 min.
      if minutes >= 60
        hours += 1
        minutes -= 60
      end
      sprintf("%2d:%02d", hours, minutes)
    end

    def copy_protected?
      result = false
      cp = get_detail_item('CopyProtected')
      result = cp.downcase == "yes" unless cp.nil?
      return result
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

    def get_listings(recurse=true)
      query_url = @base_url + '?Command=QueryContainer&Container=/NowPlaying'
      if recurse
        query_url += '&Recurse=Yes'
      end
      get_listings_from_url(query_url)
    end
      
    def get_listings_from_url(url, recurse=false)
      xml = @client.get_content(url)
      listings = TiVoItemFactory.from_xml(xml)
      if recurse
        listings.folders.each do |f|
          new_listings = get_listings_from_url(f.url)
          listings.videos.concat(new_listings) unless new_listings.nil?
        end
        listings.folders = nil
      end
      return listings
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
        # We ignore the first chunk to work around a bug in
        # http client where we see the "Auth required" digest-auth
        # header.
        first_chunk = true
        @client.get_content(url) do |c|
          if first_chunk
            first_chunk = false
            next
          end
          if block
            block.call(c)
          else
            file << c
          end
        end
      ensure
        file.close unless file.nil?
      end
    end

    private :get_listings_from_url
  end
end
