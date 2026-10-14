# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Sweep) do
  def cost(nodes, edges)
    place = described_class.new(nodes, edges).order.each_with_index.to_h
    edges.sum { |from, to, weight| place.fetch(from) > place.fetch(to) ? weight : 0 }
  end

  def ring(weights, chords)
    nodes = weights.each_index.map { format("n%02d", it) }
    [
      nodes, nodes.each_with_index.map { |node, index| [node, nodes[(index + 1) % nodes.size], weights[index]] } +
        chords.map { |from, to, weight| [nodes[from], nodes[to], weight] }
    ]
  end

  it "peels sinks to the back and sources to the front before it moves anything" do
    nodes, edges = ring([1, 2, 3, 1, 2, 3, 1, 2, 3, 3, 3, 1, 3, 1, 1, 1], [[11, 7, 3], [6, 3, 1], [12, 5, 1]])
    expect(cost(nodes, edges)).to(eq(5))
  end

  it "weighs each candidate source by what it sends out against what it takes in" do
    chords = [[0, 2, 1], [0, 7, 4], [12, 7, 4], [10, 9, 4], [0, 8, 4]]
    nodes, edges = ring([2, 1, 2, 1, 3, 1, 2, 3, 3, 1, 3, 2, 1], chords)
    expect(cost(nodes, edges)).to(eq(1))
  end

  it "settles a knot too big to search exhaustively without trying every ordering" do
    nodes, edges = ring(Array.new(24, 1), [[3, 1, 2]])
    members = nodes
    cut = Hashira::Coupling::Cut.new(members, edges)
    expect([cut.exact?, cut.edges.sum(&:last)]).to(eq([false, 1]))
  end

  it "searches every ordering of a knot of up to twelve packages" do
    nodes, edges = ring(Array.new(12, 1), [])
    expect(Hashira::Coupling::Cut.new(nodes, edges).exact?).to(be(true))
    expect(Hashira::Coupling::Cut.new(nodes + ["n12"], edges).exact?).to(be(false))
  end
end
