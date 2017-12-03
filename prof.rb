#!/usr/bin/env ruby -wKU


require_relative 'tree'
require_relative 'cyk'

require 'perftools'

TRAINING_FILENAME = 'f2-21.train.parse.noLEX'
TEST_FILENAME = 'f2-21.test.parse.noLEX'

# Reads an array of trees from the given filename.
def read_trees(filename)
  log("Reading #{filename}...")
  File.open(filename, "r") do |file|
    file.readlines.collect do |line|
      Tree.from_string(line)
    end
  end
end

# read trees
training_trees = read_trees(TRAINING_FILENAME)
test_trees = read_trees(TEST_FILENAME)
parser = CYKParser.new(training_trees)
trees = test_trees

PerfTools::CpuProfiler.start('/tmp/parser_profile') do
  (0...4).each do |number|
    tree = trees[number]
    pos = tree.get_leaves()
    guess, _ = parser.parse(pos)
    guess.unfactor() unless guess.nil?
  end
end
