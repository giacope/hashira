# frozen_string_literal: true

require "prism"

RSpec.describe Hashira::Complexity::CognitiveScore do
  def score(source)
    def_node = Prism.parse(source).value.statements.body.first
    described_class.new(def_node)
  end

  def total(source) = score(source).total

  it "charges nothing for a flat sequence of calls, but counts them" do
    scored = score("def r\n a\n b.c\n d.e.f\nend")
    expect(scored.total).to eq(0)
    expect(scored.calls).to eq(6)
  end

  it "scores a single conditional at one point" do
    expect(total("def m(a)\n x if a\nend")).to eq(1)
  end

  it "adds a nesting penalty for each level, so deep nesting compounds" do
    expect(total("def m\n if a\n  if b\n   if c\n    d\n   end\n  end\n end\nend")).to eq(6)
  end

  it "treats a block as a nesting level for the control flow inside it" do
    expect(total("def m\n if a\n  xs.each do\n   y if b\n  end\n end\nend")).to eq(4)
  end

  it "counts a case once regardless of how many arms it has" do
    expect(total("def m\n case a\n when 1 then p\n when 2 then q\n else r\n end\nend")).to eq(1)
  end

  it "handles a subjectless case and a pattern-match case" do
    expect(total("def m\n case\n when a then p\n end\nend")).to eq(1)
    expect(total("def m\n case a\n in Integer then p\n end\nend")).to eq(1)
  end

  it "keeps elsif and else flat rather than compounding like fresh nesting" do
    expect(total("def m\n if a\n  1\n elsif b\n  2\n else\n  3\n end\nend")).to eq(3)
  end

  it "scores a ternary as a single point" do
    expect(total("def m = a ? b : c")).to eq(1)
  end

  it "scores every loop and guard keyword" do
    expect(total("def m\n x while a\nend")).to eq(1)
    expect(total("def m\n x until a\nend")).to eq(1)
    expect(total("def m\n y unless a\nend")).to eq(1)
    expect(total("def m\n for i in list\n  y\n end\nend")).to eq(1)
  end

  it "counts a run of one operator once, and charges again when it changes" do
    expect(total("def m = a && b && c")).to eq(1)
    expect(total("def m = a && b || c")).to eq(2)
  end

  it "scores each rescue clause and ignores the begin, else, and ensure wrappers" do
    source = "def m\n begin\n  risky\n rescue A\n  a\n rescue B\n  b\n else\n  c\n ensure\n  d\n end\nend"
    expect(total(source)).to eq(2)
  end

  it "handles a bare rescue with neither else nor ensure clause" do
    expect(total("def m\n begin\n  risky\n rescue\n  recover\n end\nend")).to eq(1)
  end

  it "records where each increment landed" do
    increments = score("def m(a)\n x if a\nend").increments
    expect(increments.map(&:label)).to eq(["if"])
    expect(increments.first.line).to eq(2)
  end
end
