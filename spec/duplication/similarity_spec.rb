# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Similarity) do
  def ratio(left, right) = described_class.new(left, right).ratio
  it "scores identical sequences 1.0" do
    expect(ratio(%i[a b c], %i[a b c])).to(eq(1.0))
  end

  it "scores an empty sequence 0.0 from either side" do
    expect(ratio([], %i[a b])).to(eq(0.0))
    expect(ratio(%i[a b], [])).to(eq(0.0))
  end

  it "scores a one-token drift by the length-normalized LCS" do
    expect(ratio(%i[a b c d], %i[a b x d])).to(eq(0.75))
  end

  it "accepts a pair that clears the threshold" do
    expect(described_class.new(%i[a b c d], %i[a b x d]).meets?(0.75)).to(be(true))
  end

  it "rejects a pair whose token mix cannot reach the threshold" do
    expect(described_class.new(%i[a b c d], %i[a x y z]).meets?(0.8)).to(be(false))
  end

  it "still runs the full comparison when the bound alone would pass" do
    expect(described_class.new(%i[a b c d], %i[d c b a]).meets?(0.8)).to(be(false))
  end

  it "counts a repeated token only as often as both sides carry it" do
    expect(described_class.new(%i[a a a a], %i[a a b b]).meets?(0.6)).to(be(false))
  end

  it "spends each token on the other side once, however often the left repeats it" do
    expect(described_class.new(%i[a a a a a a], %i[a b c d e f]).meets?(0.5)).to(be(false))
  end

  it "still lets a genuine match through the bound" do
    expect(described_class.new(%i[a b c d], %i[a b c e]).meets?(0.75)).to(be(true))
  end
end
