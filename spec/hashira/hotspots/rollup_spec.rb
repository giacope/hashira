# frozen_string_literal: true

RSpec.describe(Hashira::Hotspots::Rollup, :aggregate_failures) do
  def score(file, cognitive) = Fakes::Score.new(file:, cognitive:)

  def complexity(scores) = Fakes::Complexity.new(scores)

  def duplication(coverage) = Fakes::Duplication.new(coverage)

  def rollup(scores: [], coverage: {}, churn: {})
    described_class.new([complexity(scores)], [duplication(coverage)], Hashira::Churn.new(churn))
  end
  it "sums cognitive complexity per file across a file's methods" do
    files = rollup(scores: [score("a.rb", 3), score("a.rb", 4), score("b.rb", 2)], churn: { "a.rb" => 1, "b.rb" => 1 })
    expect(files.files.map { it.to_h.values_at(:file, :cognitive) }).to(eq([["a.rb", 7], ["b.rb", 2]]))
  end

  it "charges a file the clone coverage duplication measured for it" do
    files = rollup(coverage: { "a.rb" => 26, "b.rb" => 6 }).files
    expect(files.map { it.to_h.values_at(:file, :duplication) }).to(contain_exactly(["a.rb", 26], ["b.rb", 6]))
  end

  it "ranks by cost times churn, so a cheap file edited constantly outranks a knot nobody opens" do
    knot = score("knot.rb", 20)
    busy = score("busy.rb", 5)
    ranked = rollup(scores: [knot, busy], churn: { "knot.rb" => 1, "busy.rb" => 9 }).files
    expect(ranked.map { it.to_h[:file] }).to(eq(["busy.rb", "knot.rb"]))
    expect(ranked.map { it.to_h[:rank] }).to(eq([45, 20]))
  end

  it "falls back to ranking by cost alone when git tells it nothing" do
    ranked = rollup(scores: [score("a.rb", 2), score("b.rb", 9)], churn: {}).files
    expect(ranked.map { it.to_h.values_at(:file, :churn, :rank) }).to(eq([["b.rb", 0, 9], ["a.rb", 0, 2]]))
  end

  it "serializes a file's cost and rank alongside its signals" do
    row = rollup(scores: [score("a.rb", 2)], churn: { "a.rb" => 3 }).files.first.to_h
    expect(row).to(eq(file: "a.rb", cognitive: 2, duplication: 0, churn: 3, cost: 2, rank: 6))
  end

  it "says whether churn weighs the rank" do
    unweighed = Hashira::Churn.new({}, Hashira::Churn::Depth.new(commits: 1, shallow: true, deep: false))
    expect([rollup.weighed?, described_class.new([], [], unweighed).weighed?]).to(eq([true, false]))
  end

  it "leaves out files that cost nothing" do
    expect(rollup(scores: [score("a.rb", 0)], churn: { "a.rb" => 7 }).files).to(be_empty)
  end

  it "zeroes the column of a skipped analyzer rather than breaking" do
    dupes = described_class.new([], [duplication("a.rb" => 9)], Hashira::Churn.new({}))
    expect(dupes.files.map { it.to_h.values_at(:file, :cognitive, :duplication) }).to(eq([["a.rb", 0, 9]]))
    costs = described_class.new([complexity([score("b.rb", 4)])], [], Hashira::Churn.new({}))
    expect(costs.files.map { it.to_h.values_at(:file, :cognitive, :duplication) }).to(eq([["b.rb", 4, 0]]))
  end
end
