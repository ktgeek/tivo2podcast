module TiVo
  module Utils
    # Do a really cheap ass text based menu
    def Utils.do_menu(tivo_items, menu_size=10)
      offset = 0
      display_items = nil
      filter_copyprotected = true
      queue = Array.new

      while (true)
        display_items = tivo_items.videos[offset, menu_size]
        puts
        display_items.each_with_index do |item, i|
          unless filter_copyprotected && item.copy_protected?
            printf("%2d) %3d | %-43.43s | %13.13s | %5s\n", i + offset,
                   item.channel, item.printable_title,
                   item.time_captured.strftime('%m/%d %I:%M%p'), item.human_duration)
          end
        end
        print "\nSelect vid, (n)ext/(p)rev #{menu_size}," +
          " # to change menu, (s)ort, (d)ownload, (q)uit: "
        $stdout.flush
        selection = nil
        input = $stdin.readline.strip
        case input
        when 'p'
          t_offset = offset - menu_size
          offset = t_offset if t_offset >= 0
        when 'n'
          t_offset = offset + menu_size
          offset = t_offset if t_offset < tivo_items.videos.length
        when '#'
          print "Enter the number of lines to display: "
          $stdout.flush
          numInput= $stdin.readline.strip.to_i
          if !numInput.nil? && numInput > 0
            menu_size=numInput
          end
        when 's'
            print "Select sort: t/T=title, d/D=date, c/C=chan, cap to reverse, other to abort:"
          $stdout.flush
          sortInput= $stdin.readline.strip
          case sortInput
          when 't','T'
            tivo_items.videos=tivo_items.videos.sort_by { |ti| ti.printable_title }
            tivo_items.videos.reverse! if sortInput=='T'
            offset=0
          when 'c','C'
            tivo_items.videos=tivo_items.videos.sort_by { |a| a.channel }
            tivo_items.videos.reverse! if sortInput=='C'
            offset=0
          when 'd', 'D'
            tivo_items.videos=tivo_items.videos.sort_by { |ti| ti.time_captured }
            tivo_items.videos.reverse! if sortInput=='D'
            offset=0
          end
        when 'd'
            break
        when 'q'
            exit(0)
        else
          selection = input.to_i if input.eql?(input.to_i.to_s)
        end
        unless selection.nil? || selection >= tivo_items.videos.length ||
            selection < 0
          queue << tivo_items.videos[selection]
        end
      end
      return queue
    end
  end
end
