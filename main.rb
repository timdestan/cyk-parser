#!/usr/bin/env ruby -wKU

require_relative 'tree'
require_relative 'cyk'

def fail(reason); puts reason; exit end
fail "usage: #{$0} training_file test_file" if ARGV.length != 2

TRAINING_FILENAME = ARGV[0]
TEST_FILENAME = ARGV[1]

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

test_trees.each do |tree|
  pos = tree.get_leaves()

  guess, _ = parser.parse(pos)

  if guess.nil?
    puts "<NO PARSE>"
  else
    puts guess.unfactor().to_s
  end
end
