# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Syntax) do
  def parse(source) = Prism.parse(source).value

  describe ".segments" do
    it "reads simple and nested constant paths" do
      node = parse("A::B::C").statements.body.first
      expect(described_class.segments(node)).to(eq(%w[A B C]))
      simple = parse("Foo").statements.body.first
      expect(described_class.segments(simple)).to(eq(%w[Foo]))
    end

    it "returns [] for non-constant nodes" do
      expect(described_class.segments(nil)).to(eq([]))
    end
  end

  describe ".rooted?" do
    it "marks ::-anchored paths absolute, plain paths not" do
      expect(described_class.rooted?(parse("::A::B").statements.body.first)).to(be(true))
      expect(described_class.rooted?(parse("A::B").statements.body.first)).to(be(false))
      expect(described_class.rooted?(parse("A").statements.body.first)).to(be(false))
    end
  end

  describe ".anchor" do
    it "anchors compact paths at the innermost scope that defines the root, else top level, else in place" do
      expect(described_class.anchor([%w[Baz]], %w[Baz Bar], Set[%w[Baz Baz]])).to(eq(%w[Baz Baz Bar]))
      expect(described_class.anchor([%w[Baz]], %w[Foo Bar], Set[%w[Foo]])).to(eq(%w[Foo Bar]))
      expect(described_class.anchor([%w[Baz]], %w[Qux Bar], Set[%w[Foo]])).to(eq(%w[Baz Qux Bar]))
    end
  end

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
      expect(described_class.direct(outer).map(&:name)).to(eq(%i[one two]))
    end

    it "handles a class body with a rescue clause" do
      tree = parse("class A\n  def x = 1\nrescue\n  nil\nend")
      node = tree.statements.body.first
      expect(described_class.direct(node)).to(eq([]))
    end

    it "handles a single-statement and an empty body" do
      single = parse("class A; def only = 1; end").statements.body.first
      expect(described_class.direct(single).map(&:name)).to(eq(%i[only]))
      empty = parse("class A; end").statements.body.first
      expect(described_class.direct(empty)).to(eq([]))
    end
  end

  describe "TypeWalk.each" do
    it "yields every class/module with its fully-qualified path" do
      tree = parse(<<~RUBY)
        module App
          module Layer
            class Thing
            end
          end

          class App::Compact
          end
        end
      RUBY
      seen = []
      Hashira::Analysis::TypeWalk.each(tree) { |_node, full| seen << full }
      expect(seen).to(eq([%w[App], %w[App Layer], %w[App Layer Thing], %w[App App Compact]]))
    end
  end

  describe "References.list" do
    def references = Hashira::Coupling::References

    it "collects outermost constant paths, not their parents separately" do
      expect(references.new.list(parse("x = A::B::C; y = D"))).to(eq([%w[A B C], %w[D]]))
    end

    it "skips the constant being defined but keeps the superclass" do
      expect(references.new.list(parse("class App::Child < Base::Parent; Used::Thing; end")))
        .to(eq([%w[Base Parent], %w[Used Thing]]))
    end

    it "ignores strings and comments" do
      expect(references.new.list(parse("# Fake::Ref\nx = 'Other::Ref'"))).to(eq([]))
    end
  end
end
