# frozen_string_literal: true

RSpec.describe(Hashira::Report::Notices, :aggregate_failures) do
  def piped = StringIO.new

  def terminal = StringIO.new.tap { |io| def io.tty? = true }
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

  it "names a crash, where it happened, and where to report it" do
    io = piped
    described_class.new(io:).crashed(ArgumentError.new("bad things").tap { it.set_backtrace(["lib/x.rb:3:in 'go'"]) })
    expect(io.string).to(eq(<<~TEXT))
      hashira: internal error — ArgumentError: bad things
        at lib/x.rb:3:in 'go'
        this is a bug in hashira — please report it at https://github.com/giacope/hashira/issues
    TEXT
  end

  it "keeps progress off a pipe, so a captured log is unchanged" do
    io = piped
    described_class.new(io:).scanning(3222, "app, lib")
    described_class.new(io:).finished(1247, "8.7")
    expect(io.string).to(be_empty)
  end

  it "shows progress on a terminal, where the wait is felt" do
    io = terminal
    described_class.new(io:).scanning(3222, "app, lib")
    described_class.new(io:).finished(1247, "8.7")
    expect(io.string).to(eq("hashira: reading 3222 files in app, lib…\nhashira: 1247 files in 8.7s\n"))
  end
end
