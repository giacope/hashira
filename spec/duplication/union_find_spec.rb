# frozen_string_literal: true

RSpec.describe Hashira::Duplication::UnionFind do
  it "collapses transitively unioned elements into one cluster" do
    sets = described_class.new
    sets.union(:a, :b)
    sets.union(:b, :c)
    sets.union(:x, :y)

    expect(sets.clusters.map(&:sort).sort).to contain_exactly(%i[a b c], %i[x y])
  end

  it "treats an untouched element as its own root" do
    expect(described_class.new.root(:solo)).to eq(:solo)
  end
end
