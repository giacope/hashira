# frozen_string_literal: true

RSpec.describe(Hashira::Report::Notices) do
  def piped = StringIO.new

  def terminal = StringIO.new.tap { |io| def io.tty? = true }
  it "explains the zeroes when the analyzed directory has no history" do
    io = piped
    described_class.new(io:).churn("lib/app")
    expect(io.string).to(eq("hashira: no git history for lib/app — hotspots are ranked by cost alone\n"))
  end
  it "names the files Prism could not parse, and how many there were" do
    io = piped
    described_class.new(io:).unparsed(4, "a.rb, b.rb, c.rb")
    expect(io.string).to(eq("hashira: 4 of the files did not parse — a.rb, b.rb, c.rb\n"))
  end
  it "keeps progress off a pipe, so a captured log is unchanged" do
    io = piped
    described_class.new(io:).scanning(3222)
    described_class.new(io:).finished(1247, "8.7")
    expect(io.string).to(be_empty)
  end
  it "shows progress on a terminal, where the wait is felt" do
    io = terminal
    described_class.new(io:).scanning(3222)
    described_class.new(io:).finished(1247, "8.7")
    expect(io.string).to(eq("hashira: reading 3222 files…\nhashira: 1247 files in 8.7s\n"))
  end
end
