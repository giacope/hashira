# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Statements, :aggregate_failures) do
  def statements(source) = described_class.new([Prism.parse(source).value.statements.body.first])

  it "reads the statements inside a method it opens, and a branch as the one statement it is" do
    expect(statements("def m\n  a\n  b\nend\n").to_a.map(&:slice)).to(eq(%w[a b]))
    expect(statements("if c\n  a\n  b\nend\n").to_a.map(&:slice)).to(eq(["if c\n  a\n  b\nend"]))
  end

  it "opens a method, a rescue clause and a when arm, and nothing else" do
    expect([statements("def m = a\n"), statements("if c\n  a\nend\n")].map(&:opened?)).to(eq([true, false]))
  end
end
