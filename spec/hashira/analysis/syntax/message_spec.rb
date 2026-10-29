# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Syntax::Message, :aggregate_failures) do
  def parse(source) = Prism.parse(source).value

  describe "#type_test?" do
    it "reads a call to is_a?, kind_of? or instance_of? as a type test, and nothing else" do
      nodes = %w[a.is_a?(B) a.kind_of?(B) a.instance_of?(B) a.size(B) is_a].map { parse(it).statements.body.first }
      expect(nodes.map { described_class.new(it).type_test? }).to(eq([true, true, true, false, false]))
      expect(described_class.new(parse("B").statements.body.first).type_test?).to(be(false))
    end
  end
end
