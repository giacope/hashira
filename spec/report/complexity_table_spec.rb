# frozen_string_literal: true

RSpec.describe(Hashira::Report::ComplexityTable) do
  it "prints the worst methods with a call count, then the per-class rollup" do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      output = capture { described_class.new(scores).print }
      expect(output).to(include("Cognitive complexity — worst methods"))
      expect(output).to(match(%r{App::Knot::Tangle#tangled\s+12\s+4\s+knot/tangle\.rb:8}))
      expect(output).to(include("Per-class rollup"))
      expect(output).to(match(/App::Knot::Tangle\s+12\s+3\s+12/))
    end
  end

  it "omits methods and classes that score zero" do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      output = capture { described_class.new(scores).print }
      expect(output).not_to(include("#simple"))
    end
  end

  it "says nothing about withheld rows when every method fits" do
    complexity(knots) do |scores|
      expect(capture { described_class.new(scores, top: 4).print }).not_to(include("more —"))
    end
  end

  it "prints nothing at all when no method scores" do
    complexity({ "lib/app/flat.rb" => "class Flat\n  def a = 1\nend\n" }) do |scores|
      expect(capture { described_class.new(scores).print }).to(be_empty)
    end
  end

  def knots
    { "lib/app/knots.rb" => "class A\n#{knot("a")}#{knot("b")}#{knot("c")}end\nclass B\n#{knot("d")}end\n" }
  end

  def knot(name) = "  def #{name}(x) = (1 if x)\n"

  it "caps both lists at --top and says how many rows each withheld" do
    complexity(knots) do |scores|
      expect(capture { described_class.new(scores, top: 1).print }).to(eq(<<~TEXT))
        Cognitive complexity — worst methods (Cog = how hard to read, Calls = message sends):

        method  Cog  Calls  Loc
        ------------------------------
        A#a       1      0  knots.rb:2
          … and 3 more — raise the cap with --top, or read them all with --json

        Per-class rollup (Cog total survives extract-method; Peak is the worst method it hides):

        class  Cog  Methods  Peak
        -------------------------
        A        3        3     1
          … and 1 more — raise the cap with --top, or read them all with --json

      TEXT
    end
  end
end
