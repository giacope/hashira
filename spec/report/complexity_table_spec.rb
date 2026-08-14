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
end
