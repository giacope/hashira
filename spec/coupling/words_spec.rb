# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Coupling::Words) do
  it "collects single lowercase words from array literals and hash keys" do
    tree = Prism.parse(<<~RUBY).value
      KINDS = { "alpha" => 1, beta: 2, **extra }
      LIST = %i[gamma delta]
      MIX = ["two words", :epsilon, 9, *rest]
      call(:zeta, "eta")
    RUBY
    expect(described_class.list(tree)).to(eq(Set.new(%w[alpha beta gamma delta epsilon])))
  end
end
