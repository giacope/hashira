# frozen_string_literal: true

RSpec.describe(Hashira::Hotspots::Rollup) do
  def score(file, cognitive)
    instance_double(Hashira::Complexity::MethodScore, file:, cognitive:)
  end

  def complexity(scores) = instance_double(Hashira::Complexity::Scores, ranked: scores)

  def duplication(coverage) = instance_double(Hashira::Duplication::Clones, coverage:)

  def rollup(scores: [], coverage: {}, churn: {})
    described_class.new(complexity(scores), duplication(coverage), Hashira::Churn.new(churn))
  end
  it "sums cognitive complexity per file across a file's methods" do
    files = rollup(scores: [score("a.rb", 3), score("a.rb", 4), score("b.rb", 2)], churn: { "a.rb" => 1, "b.rb" => 1 })
    expect(files.files.map { [it.file, it.cognitive] }).to(eq([["a.rb", 7], ["b.rb", 2]]))
  end

  it "charges a file the clone coverage duplication measured for it" do
    files = rollup(coverage: { "a.rb" => 26, "b.rb" => 6 }).files
    expect(files.map { [it.file, it.duplication] }).to(contain_exactly(["a.rb", 26], ["b.rb", 6]))
  end

  it "ranks by cost times churn, so a cheap file edited constantly outranks a knot nobody opens" do
    knot = score("knot.rb", 20)
    busy = score("busy.rb", 5)
    ranked = rollup(scores: [knot, busy], churn: { "knot.rb" => 1, "busy.rb" => 9 }).files
    expect(ranked.map(&:file)).to(eq(["busy.rb", "knot.rb"]))
    expect(ranked.map(&:rank)).to(eq([45, 20]))
  end

  it "falls back to ranking by cost alone when git tells it nothing" do
    ranked = rollup(scores: [score("a.rb", 2), score("b.rb", 9)], churn: {}).files
    expect(ranked.map { [it.file, it.churn, it.rank] }).to(eq([["b.rb", 0, 9], ["a.rb", 0, 2]]))
  end

  it "serializes a file's cost and rank alongside its signals" do
    row = rollup(scores: [score("a.rb", 2)], churn: { "a.rb" => 3 }).files.first.to_h
    expect(row).to(eq(file: "a.rb", cognitive: 2, duplication: 0, churn: 3, cost: 2, rank: 6))
  end

  it "leaves out files that cost nothing" do
    expect(rollup(scores: [score("a.rb", 0)], churn: { "a.rb" => 7 }).files).to(be_empty)
  end

  it "zeroes the column of a skipped analyzer rather than breaking" do
    dupes = described_class.new(nil, duplication("a.rb" => 9), Hashira::Churn.new({}))
    expect(dupes.files.map { [it.file, it.cognitive, it.duplication] }).to(eq([["a.rb", 0, 9]]))
    costs = described_class.new(complexity([score("b.rb", 4)]), nil, Hashira::Churn.new({}))
    expect(costs.files.map { [it.file, it.cognitive, it.duplication] }).to(eq([["b.rb", 4, 0]]))
  end
end
