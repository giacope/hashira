# frozen_string_literal: true

RSpec.describe(Hashira::Report::Columns) do
  def render(headers, rows) = capture { described_class.new(headers, rows).print }.lines(chomp: true)
  it "sizes every column to its widest cell, header included" do
    lines = render(%w[package TC], [["a", 1], ["muchlongername", 100]])
    expect(lines).to(eq(["package          TC", "-------------------", "a                 1", "muchlongername  100"]))
  end

  it "right-aligns columns that hold only numbers and left-aligns the rest" do
    lines = render(%w[file Cyc Rank], [["a.rb", "YES", 7], ["bbbbb.rb", "-", 120]])
    expect(lines.last).to(eq("bbbbb.rb  -     120"))
    expect(lines.first).to(eq("file      Cyc  Rank"))
  end

  it "leaves no trailing whitespace on any line" do
    lines = render(%w[file Cyc], [["a.rb", "-"], ["b.rb", "YES"]])
    expect(lines).to(all(satisfy { it == it.rstrip }))
  end

  it "rules to the width of the widest line, not the header" do
    lines = render(%w[method Loc], [["m", "a/very/long/path/to/somewhere.rb:12"]])
    expect(lines[1].length).to(eq(lines.last.length))
  end

  it "clips an overlong cell in the middle, keeping the telling tail" do
    long = "Extremely::Long::Namespace::Chain::MonthlySubscriptionRevenue#call"
    cell = render(%w[method Cog], [[long, 1]]).last
    expect(cell).to(start_with("Extremely::Long::Namesp…"))
    expect(cell).to(include("SubscriptionRevenue#call"))
    expect(cell.split.first.length).to(eq(described_class::CAP))
  end

  it "keeps a short cell whole" do
    expect(render(%w[a], [["short"]]).last).to(eq("short"))
  end
end
