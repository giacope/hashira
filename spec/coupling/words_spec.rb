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
    expected = [[Set.new(%w[alpha beta]), 1], [Set.new(%w[gamma delta]), 2], [Set.new(%w[epsilon]), 3]]
    expect(described_class.new(tree).lists.map { [it.words, it.line] }).to(eq(expected))
  end
end
