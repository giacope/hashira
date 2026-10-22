# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Similarity, :aggregate_failures) do
  def ratio(left, right) = described_class.new(left, right).ratio

  it "scores identical sequences 1.0" do
    expect(ratio(%i[a b c], %i[a b c])).to(eq(1.0))
  end

  it "scores an empty sequence 0.0 from either side" do
    expect(ratio([], %i[a b])).to(eq(0.0))
    expect(ratio(%i[a b], [])).to(eq(0.0))
    expect(ratio([], [])).to(eq(0.0))
  end

  it "scores a one-token drift by the length-normalized LCS" do
    expect(ratio(%i[a b c d], %i[a b x d])).to(eq(0.75))
  end

  it "scores tokens out of order by the longest run they share in order" do
    expect([ratio(%i[a b c d], %i[d c b a]), ratio(%i[a a a a], %i[a a b b])]).to(eq([0.25, 0.5]))
  end

  it "compares long sequences in near-linear time, a machine word of tokens at a step" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(ratio([:a] * 3000, [:a] + ([:b] * 2999))).to(be_within(0.001).of(1.0 / 3000))
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to(be < 0.5)
  end
end
