# frozen_string_literal: true

RSpec.describe(Hashira::Report::Warnings, :aggregate_failures) do
  def piped = StringIO.new

  def depth(commits, shallow) = Hashira::Churn::Depth.new(commits:, shallow:, deep: false)

  it "explains the zeroes when the analyzed directory has no history" do
    io = piped
    described_class.new(io:).churn("lib/app", depth(0, false))
    expect(io.string).to(eq("hashira: no git history for lib/app — hotspots are ranked by cost alone\n"))
  end

  def told(*depths, coupling: true)
    io = piped
    depths.each { described_class.new(io:).churn("lib/app", it, coupling:) }
    io.string.lines.map { it.delete_prefix("hashira: ").delete_suffix(" — #{unweighed}; #{unjudged}\n") }
  end

  def unweighed = "hotspots are ranked by cost alone"

  def unjudged = "change_coupling cannot judge"

  it "names a shallow or thin history, how many commits it holds, and what it could not judge" do
    expect(told(depth(1, true), depth(1, false)) + told(depth(0, true), coupling: false)).to(
      eq(
        [
          "shallow git history (1 commit) for lib/app", "too little git history (1 commit) for lib/app",
          "shallow git history (0 commits) for lib/app — hotspots are ranked by cost alone\n"
        ]
      )
    )
  end

  it "names the files Prism could not parse, and how many there were" do
    io = piped
    described_class.new(io:).unparsed(4, "a.rb, b.rb, c.rb")
    expect(io.string).to(eq("hashira: 4 of the files did not parse — a.rb, b.rb, c.rb\n"))
  end
end
