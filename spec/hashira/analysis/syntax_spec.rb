# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Syntax, :aggregate_failures) do
  def parse(source) = Prism.parse(source).value

  describe ".segments" do
    it "reads simple and nested constant paths" do
      node = parse("A::B::C").statements.body.first
      expect(described_class.new(node).segments).to(eq(%w[A B C]))
      simple = parse("Foo").statements.body.first
      expect(described_class.new(simple).segments).to(eq(%w[Foo]))
    end

    it "returns [] for non-constant nodes" do
      expect(described_class.new(nil).segments).to(eq([]))
    end
  end

  describe ".rooted?" do
    it "marks ::-anchored paths absolute, plain paths not" do
      expect(described_class.new(parse("::A::B").statements.body.first).rooted?).to(be(true))
      expect(described_class.new(parse("A::B").statements.body.first).rooted?).to(be(false))
      expect(described_class.new(parse("A").statements.body.first).rooted?).to(be(false))
    end
  end

  describe ".static?" do
    def node(source) = parse(source).statements.body.first

    it "calls a path static when every link is a constant, down to the root or ::" do
      expect(%w[A A::B ::A::B].map { described_class.new(node(it)).static? }).to(eq([true, true, true]))
    end

    it "calls a path hanging off an expression not static, however deep" do
      expect(%w[self::A foo::A::B a.b::C].map { described_class.new(node(it)).static? }).to(eq([false, false, false]))
    end

    it "calls anything that is not a constant path not static" do
      expect([described_class.new(nil).static?, described_class.new(node("foo")).static?]).to(eq([false, false]))
    end
  end

  describe ".place" do
    def path(source) = parse(source).statements.body.first

    it "takes a ::-rooted path as written, whatever scope encloses it, and anchors any other" do
      placed = %w[::MatchData ::A::B C].map { described_class.new(path(it)).place([%w[Drops]], Set[%w[Drops]]) }
      expect(placed).to(eq([%w[MatchData], %w[A B], %w[Drops C]]))
    end
  end

  describe ".anchor" do
    def placed(source, roots) = described_class.new(parse(source).statements.body.first).place([%w[Baz]], roots)

    it "anchors compact paths at the innermost scope that defines the root, else top level, else in place" do
      expect(placed("Baz::Bar", Set[%w[Baz Baz]])).to(eq(%w[Baz Baz Bar]))
      expect(placed("Foo::Bar", Set[%w[Foo]])).to(eq(%w[Foo Bar]))
      expect(placed("Qux::Bar", Set[%w[Foo]])).to(eq(%w[Baz Qux Bar]))
    end

    it "anchors a deep compact path at top level when only the top level defines its root" do
      expect(placed("Foo::Bar::Qux", Set[%w[Foo]])).to(eq(%w[Foo Bar Qux]))
    end

    it "nests a single-segment definition in the current scope even when a top-level namesake exists" do
      expect(described_class.new(parse("Foo").statements.body.first).place([%w[Baz]], Set[%w[Foo]])).to(eq(%w[Baz Foo]))
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
      Hashira::Analysis::TypeWalk.new(tree).walk { |_node, full| seen << full }
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
