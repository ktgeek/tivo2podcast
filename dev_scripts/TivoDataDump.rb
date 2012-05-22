#!/usr/bin/env ruby
# Copyright 2012 Keith T. Garner. All rights reserved.
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


# Adds the lib path next to the path the script is in to the head of
# the search patch
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib',
                                      'tivo'))

begin
  require 'rubygems'
rescue LoadError
  # Ruby gems wasn't found, maybe someone loaded the prereqs directly
  # Not an error, but we'll swallow it for now.
end
require 'tivopodcast/config'
require 'tivopodcast'

t2pconfig = Tivo2Podcast::Config.new
engine = Tivo2Podcast::MainEngine.new(t2pconfig)

tivo = @config.tivo_factory

puts tivo.get_listings(true, true)
