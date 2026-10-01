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

  it "keeps a cell exactly at the cap whole" do
    cell = "Billing::Subscriptions::MonthlyRevenue#reconcile"
    expect(cell.length).to(eq(described_class::CAP))
    expect(render(%w[a], [[cell]]).last).to(eq(cell))
  end

  it "never clips a location, so every path in a table can be opened as printed" do
    path = "controllers/users/omniauth_callbacks_controller.rb:58"
    line = render(%w[method Cog Loc], [["#{"Users::" * 5}Callbacks#google_oauth2_with_a_long_tail", 1, path]]).last
    expect(line).to(end_with(path))
    expect(line).to(include("Users::Users::Users::Us…_oauth2_with_a_long_tail"))
  end

  it "keeps a whole file path under the file header" do
    expect(render(%w[file Rank], [["#{"deep/" * 10}file.rb", 1]]).last).to(start_with("#{"deep/" * 10}file.rb"))
  end
end
