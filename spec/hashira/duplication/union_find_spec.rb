# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::UnionFind, :aggregate_failures) do
  it "collapses transitively linked elements into one cluster, each in the order first seen" do
    sets = described_class.new([%i[c b], %i[x y], %i[b a], %i[a c], %i[y x]])
    expect(sets.clusters).to(eq([%i[c b a], %i[x y]]))
  end

  it "orders a cluster by first appearance, not by the walk that found it" do
    expect(described_class.new([%i[a d], %i[b c], %i[c d]]).clusters).to(eq([%i[a d b c]]))
  end

  it "finds no cluster without a pair" do
    expect(described_class.new([]).clusters).to(eq([]))
  end
end
