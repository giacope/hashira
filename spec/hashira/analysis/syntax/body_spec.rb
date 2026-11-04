# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Syntax::Body, :aggregate_failures) do
  def parse(source) = Prism.parse(source).value

  describe ".direct" do
    it "finds defs directly in the body, not in nested types" do
      tree = parse(<<~RUBY)
        class Outer
          def one = 1
          def two = 2

          class Inner
            def three = 3
          end
        end
      RUBY
      outer = tree.statements.body.first
      expect(described_class.new(outer).direct.map(&:name)).to(eq(%i[one two]))
    end

    it "handles a class body with a rescue clause" do
      tree = parse("class A\n  def x = 1\nrescue\n  nil\nend")
      node = tree.statements.body.first
      expect(described_class.new(node).direct).to(eq([]))
    end

    it "handles a single-statement and an empty body" do
      single = parse("class A; def only = 1; end").statements.body.first
      expect(described_class.new(single).direct.map(&:name)).to(eq(%i[only]))
      empty = parse("class A; end").statements.body.first
      expect(described_class.new(empty).direct).to(eq([]))
    end
  end
end
