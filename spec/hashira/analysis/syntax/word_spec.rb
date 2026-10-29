# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Syntax::Word, :aggregate_failures) do
  def parse(source) = Prism.parse(source).value

  describe ".to_s / .symbol" do
    it "reads a literal's text as valid UTF-8, whatever bytes its escapes spell" do
      string, symbol = parse('["\\xFFok", :"caf\\u00e9"]').statements.body.first.elements
      expect(described_class.new(string).to_s).to(eq("\uFFFDok"))
      expect(described_class.new(string).symbol.name).to(eq("\uFFFDok"))
      expect(described_class.new(symbol).symbol).to(eq(:café))
    end
  end
end
