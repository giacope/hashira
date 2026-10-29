# frozen_string_literal: true

RSpec.describe(Hashira::Report::Notices, :aggregate_failures) do
  def piped = StringIO.new

  def terminal = StringIO.new.tap { |io| def io.tty? = true }

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
