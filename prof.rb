#!/usr/bin/env ruby -wKU


require_relative 'tree'
require_relative 'cyk'

require 'ruby-prof'

TRAINING_FILENAME = 'data/f2-21.train.parse.noLEX'
TEST_FILENAME = 'data/f2-21.test.parse.noLEX'

# Reads an array of trees from the given filename.
def read_trees(filename, limit=nil)
  log("Reading #{filename}...")
  File.open(filename, "r") do |file|
    lines = file.readlines
    lines = lines.take(limit) unless limit.nil?
    lines.map do |line|
      Tree.from_string(line)
    end
  end
end

result = RubyProf.profile do
  training_trees = read_trees(TRAINING_FILENAME, 1000)
  # test_trees = read_trees(TEST_FILENAME, limit=1000)
  parser = CYKParser.new(training_trees)
end

# test_trees.each do |tree|
#   pos = tree.get_leaves()
#   guess, _ = parser.parse(pos)
#   guess.unfactor() unless guess.nil?
# end

puts "Profile for reading trees"
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT)
