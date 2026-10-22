# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Smells::Parameters, :aggregate_failures) do
  it "names destructured parameters through a named splat" do
    node = Prism.parse("def m((a, *b, c)) = a").value.statements.body.first
    expect(described_class.new(node).names).to(eq(%i[a b c]))
  end
end
