# frozen_string_literal: true

RSpec.describe(Hashira::Hotspots::Rollup) do
  def score(file, cognitive)
    instance_double(Hashira::Complexity::MethodScore, file:, cognitive:)
  end

  def cluster(mass, *files)
    instance_double(Hashira::Duplication::Cluster, masses: files.map { [it, mass] })
  end

  def complexity(scores) = instance_double(Hashira::Complexity::Scores, ranked: scores)

  def duplication(clusters) = instance_double(Hashira::Duplication::Clones, clusters:)

  def rollup(scores: [], clusters: [], churn: {})
    described_class.new(complexity(scores), duplication(clusters), Hashira::Churn.new(churn))
  end
  it "sums cognitive complexity per file across a file's methods" do
    files = rollup(scores: [score("a.rb", 3), score("a.rb", 4), score("b.rb", 2)], churn: { "a.rb" => 1, "b.rb" => 1 })
    expect(files.files.map { [it.file, it.cognitive] }).to(eq([["a.rb", 7], ["b.rb", 2]]))
  end
  it "charges a file the mass of every clone site it holds" do
    files = rollup(clusters: [cluster(10, "a.rb", "a.rb"), cluster(6, "a.rb", "b.rb")]).files
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
  it "leaves out files that cost nothing" do
    expect(rollup(scores: [score("a.rb", 0)], churn: { "a.rb" => 7 }).files).to(be_empty)
  end
  it "zeroes the column of a skipped analyzer rather than breaking" do
    dupes = described_class.new(nil, duplication([cluster(9, "a.rb")]), Hashira::Churn.new({}))
    expect(dupes.files.map { [it.file, it.cognitive, it.duplication] }).to(eq([["a.rb", 0, 9]]))
  end
end
