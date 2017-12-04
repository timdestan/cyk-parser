#!/usr/bin/env ruby -wKU


require_relative 'tree'
require_relative 'cyk'

require 'ruby-prof'

def fail(reason); $stderr.puts reason; exit(1) end

MODES = {
  "HTML" => :html,
  "DOT" => :dot
}

if ARGV.length != 1 || !MODES.has_key?(ARGV[0].upcase)
  fail("usage: #{$0} #{MODES.keys.join("|")}")
end

mode = MODES[ARGV[0].upcase]

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
  test_trees = read_trees(TEST_FILENAME, 10)
  parser = CYKParser.new(training_trees)

  test_trees.each do |tree|
    pos = tree.get_leaves()
    guess, _ = parser.parse(pos)
    guess.unfactor() unless guess.nil?
  end
end

case mode
when :dot
  RubyProf::DotPrinter.new(result).print(STDOUT)
when :html
  RubyProf::GraphHtmlPrinter.new(result).print(STDOUT, :min_percent => 0)
else
  fail("Unexpected mode: #{mode}")
end
