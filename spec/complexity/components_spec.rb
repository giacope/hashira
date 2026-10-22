# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Components) do
  def components(graph) = described_class.new(graph).to_a.map(&:sort).sort

  def mutual(graph)
    reach = graph.to_h { |node, _| [node, Hashira::Coupling::Reach.new(graph).from(node) | [node]] }
    graph.keys.map { |node| graph.keys.select { reach[node].include?(it) && reach[it].include?(node) } }.uniq.sort
  end

  it "groups nodes that reach each other and leaves the rest alone" do
    graph = { a: [:b], b: %i[c a], c: [:d], d: [:c], e: [:e], f: [:a], g: [] }
    expect(components(graph)).to(eq([%i[a b], %i[c d], [:e], [:f], [:g]]))
  end

  it "keeps a node apart from a cycle it only reaches" do
    graph = { a: %i[b c], b: [:a], c: [], d: [:a] }
    expect(components(graph)).to(eq([%i[a b], [:c], [:d]]))
  end

  it "walks a long chain without growing the call stack" do
    size = 50_000
    graph = (0...size).to_h { [it, [it + 1]] }.merge(size => [0])
    expect(components(graph)).to(eq([(0..size).to_a]))
  end

  it "agrees with mutual reachability on random graphs" do
    random = Random.new(7)
    graphs = Array.new(20) { (0...12).to_h { [it, (0...12).to_a.sample(random.rand(3), random:)] } }
    graphs.each { expect(components(it)).to(eq(mutual(it))) }
  end
end
