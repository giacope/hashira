# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Coupling::Words, :aggregate_failures) do
  it "collects the single lowercase words of each array literal and hash's keys, literal by literal" do
    tree = Prism.parse(<<~RUBY).value
      KINDS = { "alpha" => 1, beta: 2, **extra }
      LIST = %i[gamma delta]
      MIX = ["two words", :epsilon, 9, *rest]
      call(:zeta, "eta")
    RUBY
    every = described_class::Literal.new(Set.new(%w[alpha beta gamma delta epsilon zeta eta]), 0)
    expected = [[%w[alpha beta], "k.rb:1"], [%w[delta gamma], "k.rb:2"], [%w[epsilon], "k.rb:3"]]
    expect(described_class.new(tree).lists.map { [it.shared(every).sort, it.site("k.rb")] }).to(eq(expected))
  end
end
