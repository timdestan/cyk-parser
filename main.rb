#!/usr/bin/env ruby -wKU

require_relative 'tree'
require_relative 'cyk'

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

def time_2_str(sec)
  sec = sec.to_i
  min = sec / 60
  sec = sec % 60
  hour = min / 60
  min = min % 60
  "%d hours, %d minutes, %d seconds" % [hour, min, sec]
end

begin_time = Time.now()

# read trees
training_trees = read_trees(TRAINING_FILENAME)
test_trees = read_trees(TEST_FILENAME)
parser = CYKParser.new(training_trees)

require 'monitor'
$lock = Monitor.new()
$donelock = Monitor.new()

$tree_done = 0

MAX_SENTENCES = 100

$next_index = 0
$num_test_trees = [test_trees.length(), MAX_SENTENCES].min

$stderr.puts("Attempting to parse #{$num_test_trees} sentences.")

NUM_THREADS = 1

output_strings = Array.new($num_test_trees)
timings = Array.new($num_test_trees)
threads = []

$time_100 = Time.now()
$time_2000 = Time.now()

def do_work(parser, trees, output_strings, timings)
  number = nil
  loop do
    $lock.synchronize do
      unless number.nil?
        $stderr.puts "Completed parse number #{number} in #{time_2_str(timings[number])}."
      end
      number = $next_index
      $next_index += 1
      if number >= $num_test_trees
        $stderr.puts "Thread done, returning."
        $stderr.flush()
        return # done
      else
        $stderr.puts "Starting parse for sentence number #{number}."
        $stderr.flush()
      end
    end
    
    tree = trees[number]
    pos = tree.get_leaves()

    # Compute a guess parse.
    start_parse = Time.now()
    guess, _ = parser.parse(pos)
    end_parse = Time.now()

    timings[number] = (end_parse - start_parse)

    # Check if the parse failed. We'll indicate this with a nil return value.
    if guess.nil?
      output_strings[number] = "No parse found for this tree."
    else
      output_strings[number] = guess.unfactor().to_s
    end

    $donelock.synchronize do
      $tree_done += 1
      if $tree_done == 100
        $time_100 = Time.now()
      elsif $tree_done == $num_test_trees
        $time_2000 = Time.now()
      end
    end
  end
end


(0...NUM_THREADS).each do |tid|
  threads << Thread.new { do_work(parser, test_trees, output_strings, timings) }
end

threads.each do |t|
  t.join()
end

output_strings.each do |str|
  $stdout.puts str
end

duration_100 = $time_100 - begin_time
duration_2000 = $time_2000 - begin_time

$stderr.puts "Time to parse 100: #{time_2_str(duration_100)}."
$stderr.puts "Time to parse 2000: #{time_2_str(duration_2000)}."

def mean(vals)
  if (vals.length == 0)
    return Float::NAN
  else
    total = 0
    vals.each do |value|
      total += value
    end
    return total / vals.length()
  end
end

mu = mean(timings)
$stderr.puts "Mean parse time: #{time_2_str(mu)}"
timings.each_with_index do |timing,i1|
  $stderr.puts "Time #{i1}: #{time_2_str(timing)}"
end
