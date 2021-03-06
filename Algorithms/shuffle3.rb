#!/usr/bin/env ruby
require 'rgl/adjacency'
require 'yaml'

class WeightedUnDirectedGraph < RGL::AdjacencyGraph
  def initialize(edgelist_class = Set, *other_graphs)
    super
    @weights = {}
  end

  def self.[] (*a)
    result = new
    0.step(a.size-2, 3) { |i| result.add_edge(a[i], a[i+1], a[i+2]) }
    result
  end

  def to_s
    (edges.sort_by { |e| e.to_s } +
     isolates.sort_by {|n| n.to_s}).map { |e| e.to_s }.join("\n")
  end

  def isolates
    edges.inject(Set.new(vertices)) { |iso, e| iso -= [e.source, e.target] }
  end

  def add_edge(u, v, w)
    super(u,v)
    @weights[[u,v]] = w
  end

  def weight(u, v)
    @weights[[u,v]]
  end

  def remove_edge(u, v)
    super
    @weights.delete([u,v])
  end

  def remove_vertex(v)
    super
    @weights.delete_if { |k, _| k.include?(v) }
  end

  def edge_class
    WeightedUnDirectedEdge
  end

  def edges
    result = []
    c = edge_class
    each_edge { |u,v| result << c.new(u, v, self) }
    result
  end

  def top_edge
    key = @weights.select {|k, v| v == @weights.values.max }.keys.sample
    [key, @weights[key]]
  end
end

class WeightedUnDirectedEdge < RGL::Edge::UnDirectedEdge
  def initialize(a, b, g)
    super(a,b)
    @graph = g
  end

  def weight
    @graph.weight(source, target)
  end

   def to_s
     "(#{source}-#{weight}-#{target})"
   end
end

class Pod < WeightedUnDirectedGraph
  attr_accessor :students, :previous_pairs

  # need this initializer because the super duper initializer
  # takes specific arguments
  # _students_ is an array of the students github handles
  # _previous_pairs_ is a hash in format { ["student1", "student2"] => weight }
  def self.init_with_options(students, previous_pairs = {})
    p = Pod.new
    p.students = students
    p.previous_pairs = previous_pairs
    p
  end

  def pop
    e = top_edge
    remove_edge(*e[0])
    remove_vertex(e[0][0])
    remove_vertex(e[0][1])
    e
  end

  def build_graph
    # latest edge weights from `pair_value`
    self.students.combination(2).each do |pair|
      add_edge(*pair.sort, pair_value(pair))
    end
  end

  def pair_students
    # every time students are paired, rebuild the graph with the
    build_graph

    pairs = []
    until pairs.length == students.length / 2
      # randomly selects a pair from the pairs with the highest edge weight
      # this is still not perfect.
      pairs << self.pop
    end

    adjusted_weight_edges = pairs.map do |p|
      x = p.clone
      x[1] = x[1]/2 # could be average pair weighting
      x
    end

    update_pair_log adjusted_weight_edges
    pairs
  end

  def update_pair_log adjusted_weights
    self.previous_pairs.merge!(Hash[*adjusted_weights.flatten(1)])
  end

  def pair_value(pair)
    if self.previous_pairs.keys.include?(pair)
      self.previous_pairs[pair]
    else
      100
    end
  end
end


if ARGV[0]
  students_filename = ARGV[0]
else
  print "\nPlease enter filename for student list: "
  students_filename = gets.chomp
end

pair_log = {}

if ARGV[1]
  pair_log_filename = ARGV[1]
  pair_log = YAML.load_file(pair_log_filename)
else
  if File.exist?("pair_log")
    pair_log = YAML.load_file("pair_log")
  end
end

pair_log_filename ||= "pair_log"

students = File.readlines(students_filename).map(&:chomp)
g = Pod.init_with_options(students, pair_log)

File.open("pairs_for_#{ students_filename }_#{Time.new.to_i.to_s}", "w") do |f|
  day_pairs = g.pair_students
  p Hash[*day_pairs.flatten(1)].keys
  f.puts Hash[Hash[*day_pairs.flatten(1)].keys]
end

File.open(pair_log_filename, "w") do |f|
  f.puts g.previous_pairs.to_yaml
end

