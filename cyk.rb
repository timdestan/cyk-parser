# CYK Parser Implementation File
# Author: Tim Destan
# Email: tim.destan@gmail.com

require 'set'

def log(str)
  $stderr.puts(str) if $DEBUG
end

class CykError < Exception
  def initialize(*args)
    super(*args)
  end
end

# Class for a 3-dimensional array.
class Array3D
  # Default value for Array elements that have not been assigned to.
  # Would make this settable if I wanted to make this more general.
  DEFAULT_VALUE = nil

  # Construct this array with optional size parameters.
  # Must specify all 3 dimensions.
  def initialize(sizeI, sizeJ, sizeK)

    @sizeI,@sizeJ,@sizeK = sizeI, sizeJ, sizeK
    @me = Hash.new()
    #@k_set_indices = Hash.new()
    sizeI.times do |i|
      #@k_set_indices[i] = Hash.new()
      @me[i] = Hash.new()
      sizeJ.times do |j|
        #@k_set_indices[i][j] = Set.new()
        @me[i][j] = Hash.new(DEFAULT_VALUE)
      end
    end
  end

  def get_table()
    return @me
  end

  # Not used
  def size()
    [@sizeI, @sizeJ, @sizeK]
  end

  # Verify that three indices were provided.
  # Could check range here as well. (not used)
  def check_index_tuple(*args)
    raise ArgumentError.new("Expected exactly 3 indices.") if args.length != 3
  end

  def get_k_set_indices(i,j)
    return @me[i][j].keys
    #return @k_set_indices[i][j]
  end

  def [](i,j,k)
    @me[i][j][k]
  end

  def []=(i,j,k, value)
    #@k_set_indices[i][j] << k
    @me[i][j][k] = value
  end
end

# Class that implements a CYK Parser.
class CYKParser

  # Using to indicate a root node in place of its children.
  LeafNode = Object.new()
  TopSymbol = "TOP"

  # Initialize the parser.
  # Takes an array of trees in CNF.
  def initialize(trees)
    @trees = trees
    # Declare the stuff we're going to use later so
    # it's all in one place.
    @pos = []                       # Array of the parts of speech (strings)
    @nt_2_index = Hash.new(nil)     # Tracks array indices for each NT
    @is_pos = []                    # Tells whether an NT is a POS or not.
    @nt = []                        # Array of all NTs.
    @num_nt = 0                     # Number of nonterminals.
    @rules = []                     # Array of all the rules.
    
    @lhs_rhs_counts = Hash.new(0)   # Map of pairs of (LHS,RHS) to their frequencies.
    
    @lhs_2_rhs = {}                 # Maps LHS to list of all associated RHS's.

    @lhs_rhs_prob = Hash.new(0)     # Map of pairs of (LHS,RHS) to their probabilities in the PCFG.

    @factored = []

    @b_2_c_2_a_2_p = []

    # Now compute all that stuff (takes a while) 
    left_factor()                   # Left factor the grammar.
    determine_parts_of_speech()     # Find all the parts of speech from all those trees.
    extract_rules()                 # Extract all the CFG rules from the left-factored trees.
    compute_probabilities()         # Compute the probabilities for the PCFG model.
  end

  def left_factor()
    log("Left factoring the training trees...")
    @trees.each do |tree|
      tree.left_factor!
    end
  end

  def determine_parts_of_speech()
    log("Determining all parts of speech found in training set...")
    @pos = @trees.collect do |tree|
      tree.get_leaves()
    end.flatten.uniq
  end

  def extract_rules()
    log("Extracting all CFG rules from training set...")
    @rules = Array.new(10 * @trees.length)
    capacity = 0
    @trees.each do |tree|
      some_trees = tree.get_all_trees()
      @rules[capacity, some_trees.length] = some_trees
      capacity += some_trees.length
    end
    # We don't want to include POS -> rules
    @rules = @rules.select do |x|
      not x.nil? and not @pos.include? x.head
    end
  end

  def compute_probabilities()
    log("Computing probabilities for CFG rules...")

    @rules.each do |rule|
      @lhs_rhs_counts[[rule.lhs, rule.rhs]] += 1
      @lhs_2_rhs[rule.lhs] ||= []
      @lhs_2_rhs[rule.lhs] << rule.rhs
    end

    @nt = @pos + @lhs_2_rhs.keys
    @nt.each_with_index do |nt,index|
      @nt_2_index[nt] = index
      @is_pos[index] = (@pos.include? nt)
      @factored[index] = (nt.index("~") != nil)
    end
    @num_nt = @nt.length()

    @lhs_rhs_counts.each_key do |lhs,rhs|
      # Store Log Probabilities.
      ai = @nt_2_index[lhs]
      unless lhs == TopSymbol
        b,c = rhs.split(" ")
        # if b.nil? or c.nil?
        #   raise CykError.new("B-C split failed #{rhs} not found #{rhs.class}")
        # end
        bi = @nt_2_index[b]
        ci = @nt_2_index[c]
        @b_2_c_2_a_2_p[bi] ||= []
        @b_2_c_2_a_2_p[bi][ci] ||= []
        @b_2_c_2_a_2_p[bi][ci][ai] = Math.log(Float(@lhs_rhs_counts[[lhs,rhs]]) / (@lhs_2_rhs[lhs].length))
        @lhs_rhs_prob[[lhs,rhs]] = @b_2_c_2_a_2_p[bi][ci][ai]
      end  
    end
  end

  def check_tags(tag_indexes)
    if tag_indexes.any? { |value| value.nil? }
      raise CykError.new "Tag found in test data that was never used in training data. Should never happen."
    end
    if tag_indexes.any? { |value| not @is_pos[value] }
      raise CykError.new "Tag used for word that is not a part of speech tag."
    end
  end

  # Parses a sentence and returns the most likely
  # parse tree in accordance with our grammar.
  def parse(sentence)

    n = sentence.length()
    memo = Array3D.new(n+1, n+1, @num_nt)
    ht = memo.get_table()
    bp = Array3D.new(n+1, n+1, @num_nt)
    # set up all the tags from the sentence.
    
    tag_indexes = sentence.map { |t| @nt_2_index[t] }
    check_tags(tag_indexes)

    tag_indexes.each_with_index do |tag_index,index|
      ht[index][index+1][tag_index] = 0.0 # Log 1
      bp[index,index+1,tag_index] = LeafNode
    end

    c_2_a_2_p = nil
    a_2_p = nil
    new_prob = nil
    ht_target = nil

    (2..n).each do |s|
      (0..n-s).each do |b|
        (b+1..b+s-1).each do |m|
          ht[b][m].each do |bi,biv|
            next if @factored[bi]
            c_2_a_2_p = @b_2_c_2_a_2_p[bi]
            unless c_2_a_2_p.nil?
              ht[m][b+s].each do |ci,civ|
                ht_target = ht[b][b+s]
                a_2_p = c_2_a_2_p[ci]
                unless a_2_p.nil?
                  a_2_p.each_with_index do |prob,ai|
                    next if prob.nil? 
                    new_prob = prob + biv + civ
                    if (ht_target[ai].nil? or new_prob > ht_target[ai])
                      ht_target[ai] = new_prob
                      bp[b,b+s,ai] = [[b,m,bi],[m,b+s,ci]]
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # find best
    top_rhses = @lhs_2_rhs[TopSymbol]  
    best_parse = nil
    best_prob = -Float::INFINITY
    (0..@num_nt).each do |i1|
      unless ht[0][n][i1].nil?
        if top_rhses.include? @nt[i1] and (ht[0][n][i1] > best_prob)
          best_parse = i1
          best_prob = ht[0][n][i1]
        end
      end
    end

    # build tree
    if best_parse.nil?
      return nil
    else
      tree = build_tree(bp, 0, n, best_parse)
      if tree.nil?
        return nil
      else
        rv = Tree.new()
        rv.head = TopSymbol
        rv.subtrees = [tree]
        return rv
      end
    end
  end

  def build_tree(bp,i,j,k)
    t = Tree.new()
    case bp[i,j,k]
    when LeafNode
      t.head = @nt[k]
      t.subtrees = "W#{@nt[k]}"
      return t
    else
      t.head = @nt[k]
      lc, rc = bp[i,j,k]
      
      l1,l2,l3 = lc
      r1,r2,r3 = rc
      t.subtrees = [ build_tree(bp,l1,l2,l3), build_tree(bp,r1,r2,r3)]
      return t
    end
  end

end
