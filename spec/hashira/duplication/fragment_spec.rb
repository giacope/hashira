# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Fragment, :aggregate_failures) do
  def fragment(source)
    plain = Hashira::Duplication::Setting.new(declarative: false, recurring: [])
    root = Prism.parse(source).value.statements.body.first
    described_class.new("f.rb", [root], Hashira::Duplication::Walks.new, plain)
  end

  it "reads the statements inside a method it opens, and a branch as the one statement it is" do
    expect(fragment("def m\n  a\n  b\nend\n").statements.map(&:slice)).to(eq(%w[a b]))
    expect(fragment("if c\n  a\n  b\nend\n").statements.map(&:slice)).to(eq(["if c\n  a\n  b\nend"]))
  end
end
