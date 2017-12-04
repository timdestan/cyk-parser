class Tree
  attr_accessor :head, :subtrees

  # Configure and return a tree from the
  # provided string.
  #
  def self.from_string(str)
    t = new()
    t.configure(str.chomp)
    t
  end

  # Construct this tree
  def initialize()
    @subtrees = []
  end

  # Clone this tree.
  def clone()
    copy = Tree.new
    copy.head = @head
    copy.subtrees = @subtrees.clone()
    return copy
  end

  # Consumes one of the given character from the string and
  # returns the resulting string.
  def consume(str, char)
    raise AssertionError.new("Expected '#{char}'") unless str[0] == char
    return str[1..-1].strip
  end

  # Name of the root node at this level.
  def lhs
    @head
  end

  # Name of the right hand side of the production
  def rhs
    if @subtrees.is_a? Array
      @subtrees.collect { |t| t.lhs }.join(" ")
    else
      @subtrees
    end
  end

  def child_names
    return @subtrees.collect { |t| t.head }
  end

  def am_i_real?
    @head.index("~").nil?
  end

  def unfactor
    unfactored_subtrees = (@subtrees.is_a? Array) ? @subtrees.collect { |t| t.unfactor }.flatten : @subtrees
    if am_i_real?
      t = Tree.new()
      t.head = @head
      t.subtrees = unfactored_subtrees
      return t
    else
      return unfactored_subtrees
    end
  end

  def left_factor!
    if @subtrees.is_a? Array
      if @subtrees.length > 2
        first, *rest = @subtrees
        # Make standin for the last n-1 trees.
        standin = Tree.new()
        # Mash the names together with ~
        standin.head = "#{lhs}~#{first.lhs}"
        standin.subtrees = rest
        @subtrees = [first, standin]
      end
      # Left factor the subtrees.
      @subtrees.each do |tree|
        tree.left_factor!
      end
    else
      # OK, do nothing. Don't care about unaries.
    end
  end

  # Creates the CFG string
  def to_cfg_string
    lhs() + " -> " + rhs()
  end

  def get_all_trees
    all = []
    if @subtrees.is_a? Array
      # Don't include final pre-terminal nodes.
      all += [self]
      @subtrees.each do |tree|
        all += tree.get_all_trees
      end
    end
    return all
  end

  # Gets just the parts of speech tags from the leaves.
  def get_leaves
    if @subtrees.is_a? Array
      return @subtrees.collect do |tree|
        tree.get_leaves()
      end.flatten
    else
      # We are a part of speech tag
      return [@head]
    end
  end

  # Configures this tree from a string.
  def configure(str)
    str = consume(str, "(")
    # atrocious performance
    @head = ""
    while str[0] != " "
      @head += str[0]
      str = str[1..-1]
    end
    str.strip!
    case str[0]
    when "("
      while (str[0] == "(")
        @subtrees << (tree = Tree.new())
        str = tree.configure(str)
      end
    else
      # atrocious performance
      # Seriously, this could be done so much smarter.
      @subtrees = ""
      while str[0] != ")"
        @subtrees += str[0]
        str = str[1..-1]
      end
    end
    str = consume(str, ")")
    return str
  end

  # Does this node represent a unary rule?
  #
  def is_unary?
    (not @subtrees.is_a? Array) or (@subtrees.length == 1)
  end

  class PrintMode
    PRETTY = 1
    COMPACT = 2
  end

  def to_s; format(PrintMode::COMPACT) end
  def pretty_print; format(PrintMode::PRETTY) end

  def format(mode, padding=0)
    rv = ''
    rv += ('  ' * padding) if mode == PrintMode::PRETTY
    rv += "(#{@head} "
    if @subtrees.is_a? Array
      rv += "\n" if mode == PrintMode::PRETTY
      sep = (mode == PrintMode::PRETTY) ? "\n" : ' '
      rv += @subtrees.map do |tr|
        tr.format(mode, padding + 1)
      end.join(sep)
    else # string
      rv += ' ' if mode == PrintMode::PRETTY
      rv += @subtrees.to_s
    end
    rv + ")"
  end
end
