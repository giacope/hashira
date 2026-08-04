# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Smells::Parameters) do
  it "names destructured parameters through a named splat" do
    node = Prism.parse("def m((a, *b, c)) = a").value.statements.body.first
    expect(described_class.names(node)).to(eq(%i[a b c]))
  end
end
