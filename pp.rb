#!/usr/bin/env ruby -wKU

require_relative 'tree'

def fail(reason); puts reason; exit end
fail "usage: #{$0} FILENAME(S)" if ARGV.empty?

ARGF.each do |f|
  puts Tree.from_string(f)
end
