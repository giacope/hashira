# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Coupling::Words) do
  it "collects the single lowercase words of each array literal and hash's keys, literal by literal" do
    tree = Prism.parse(<<~RUBY).value
      KINDS = { "alpha" => 1, beta: 2, **extra }
      LIST = %i[gamma delta]
      MIX = ["two words", :epsilon, 9, *rest]
      call(:zeta, "eta")
    RUBY
    expected = [Set.new(%w[alpha beta]), Set.new(%w[gamma delta]), Set.new(%w[epsilon])]
    expect(described_class.lists(tree)).to(eq(expected))
  end
end
