# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Complexity::CognitiveScore) do
  def score(source)
    described_class.new(Prism.parse(source).value.statements.body.first)
  end

  def total(source) = score(source).total
  it "charges nothing for a flat sequence of calls, but counts them" do
    scored = score("def r\n a\n b.c\n d.e.f\nend")
    expect(scored.total).to(eq(0))
    expect(scored.calls).to(eq(6))
  end

  it "scores a single conditional at one point" do
    expect(total("def m(a)\n x if a\nend")).to(eq(1))
  end

  it "adds a nesting penalty for each level, so deep nesting compounds" do
    expect(total("def m\n if a\n  if b\n   if c\n    d\n   end\n  end\n end\nend")).to(eq(6))
  end

  it "treats a block as a nesting level for the control flow inside it" do
    expect(total("def m\n if a\n  xs.each do\n   y if b\n  end\n end\nend")).to(eq(4))
  end

  it "counts a case once regardless of how many arms it has" do
    expect(total("def m\n case a\n when 1 then p\n when 2 then q\n else r\n end\nend")).to(eq(1))
  end

  it "handles a subjectless case and a pattern-match case" do
    expect(total("def m\n case\n when a then p\n end\nend")).to(eq(1))
    expect(total("def m\n case a\n in Integer then p\n end\nend")).to(eq(1))
  end

  it "charges the else of an unless exactly as the else of an if" do
    expect(total("def m\n unless a\n  1\n else\n  2\n end\nend")).to(eq(2))
    expect(score("def m\n unless a\n  1\n else\n  if b then 2 end\n end\nend").increments.map(&:label))
      .to(eq(%w[unless else if]))
    expect(total("def m\n unless a\n  1\n else\n  if b then 2 end\n end\nend")).to(eq(4))
  end

  it "keeps elsif and else flat rather than compounding like fresh nesting" do
    expect(total("def m\n if a\n  1\n elsif b\n  2\n else\n  3\n end\nend")).to(eq(3))
  end

  it "scores a ternary as a single point at the top level" do
    expect(total("def m = a ? b : c")).to(eq(1))
  end

  it "charges a ternary its nesting like an if, and nests both of its arms" do
    expect(total("def m\n if a\n  b ? c : d\n end\nend")).to(eq(3))
    expect(total("def m = a ? (b ? c : d) : e")).to(eq(3))
    expect(total("def m = a ? b : (c ? d : e)")).to(eq(3))
    expect(total("def m = xs.map { it ? 1 : 2 }")).to(eq(2))
  end

  it "leaves the condition of a ternary at the ternary's own level" do
    expect(total("def m = (a ? b : c) ? d : e")).to(eq(2))
  end

  it "scores a rescue modifier like a rescue clause, nesting only the fallback" do
    expect(total("def m = risky rescue nil")).to(eq(1))
    expect(total("def m\n if a\n  risky rescue nil\n end\nend")).to(eq(3))
    expect(total("def m = (a ? b : c) rescue d")).to(eq(2))
    expect(total("def m = risky rescue (a ? b : c)")).to(eq(3))
    expect(score("def m = risky rescue nil").increments.map(&:label)).to(eq(["rescue"]))
  end

  it "scores every loop and guard keyword" do
    expect(total("def m\n x while a\nend")).to(eq(1))
    expect(total("def m\n x until a\nend")).to(eq(1))
    expect(total("def m\n y unless a\nend")).to(eq(1))
    expect(total("def m\n for i in list\n  y\n end\nend")).to(eq(1))
  end

  it "counts a run of one operator once, and charges again when it changes" do
    expect(total("def m = a && b && c")).to(eq(1))
    expect(total("def m = a && b || c")).to(eq(2))
  end

  it "scores each rescue clause and ignores the begin, else, and ensure wrappers" do
    source = "def m\n begin\n  risky\n rescue A\n  a\n rescue B\n  b\n else\n  c\n ensure\n  d\n end\nend"
    expect(total(source)).to(eq(2))
  end

  it "handles a bare rescue with neither else nor ensure clause" do
    expect(total("def m\n begin\n  risky\n rescue\n  recover\n end\nend")).to(eq(1))
  end

  it "counts calls even when asked before the score" do
    expect(score("def r\n a.b\nend").calls).to(eq(2))
  end

  it "nests the body of a loop or a case one level deeper" do
    expect(total("def m\n while a\n  x if b\n end\nend")).to(eq(3))
    expect(total("def m\n case a\n when 1 then x if b\n end\nend")).to(eq(3))
  end

  it "scores the condition of an if, not only its body" do
    expect(total("def m\n if a && b\n  c\n end\nend")).to(eq(2))
  end

  it "nests the else branch like the if branch" do
    expect(total("def m\n if a\n  b\n else\n  c if d\n end\nend")).to(eq(4))
  end

  it "scores what sits inside a ternary" do
    expect(total("def m = a ? b && c : d")).to(eq(2))
  end

  it "scores the body, rescue, else and ensure of a begin, nesting only the rescue" do
    source = "def m\n begin\n  w if a\n rescue\n  x if b\n else\n  y if c\n ensure\n  z if d\n end\nend"
    expect(total(source)).to(eq(6))
  end

  it "records where each increment landed" do
    increments = score("def m(a)\n x if a\nend").increments
    expect(increments.map(&:label)).to(eq(["if"]))
    expect(increments.first.line).to(eq(2))
  end
end
