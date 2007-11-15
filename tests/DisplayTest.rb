#!/usr/bin/env ruby
# Adds the path the script is in to the head of the search patch
$:.unshift File.expand_path(File.join(File.dirname(__FILE__)))

require 'TiVo.rb'

def do_menu(tivo_items, menu_size=10)
  offset = 0
  display_items = tivo_items.videos[offset, offset + menu_size]

  while (true)
    display_items.each_with_index do |item, i|
      printf("%2d) %3d | %-43.43s | %13.13s | %5s\n", i, item.channel,
             item.printable_title, item.time_captured.strftime('%m/%d %I:%M%p'),
             item.duration)
    end
    print "\nSelect a video, n for next #{menu_size}, " +
      "p for previous #{menu_size}: "
    selection = nil
    input = $stdin.readline.strip
    case input
    when 'p':
        t_offset = offset - menu_size
      offset = t_offset if t_offset > 0
    when 'n':
        t_offset = offset + menu_size
      offset = t_offset if t_offset > tivo_items.videos.length
    else
      selection = input.to_i
    end
    break unless selection.nil? || selection >= display_items.length
  end
  return display_items[selection]
end

xml = IO.read('sample/NowPlaying.xml')
tivo_items = TiVo::TiVoItemFactory.from_xml(xml)

sitem = do_menu(tivo_items)

printf("%3d | %-50.50s | %13.13s | %5s\n", sitem.channel,
       sitem.printable_title, sitem.time_captured.strftime('%m/%d %I:%M%p'),
       sitem.duration)

