# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Scores) do
  it "ranks methods by cognitive complexity, worst first" do
    complexity(FixtureHelper::COMPLEX_FILES) do |scores|
      worst = scores.ranked.first
      expect(worst.subject).to(eq("App::Knot::Tangle#tangled"))
      expect(worst.cognitive).to(eq(12))
      expect(worst.calls).to(eq(4))
    end
  end
  it "labels instance methods with # and singleton methods with ." do
    complexity(FixtureHelper::COMPLEX_FILES) do |scores|
      subjects = scores.ranked.map(&:subject)
      expect(subjects).to(include("App::Knot::Tangle.helper", "App::Knot::Tangle#simple"))
    end
  end
  it "rolls complexity up per class — the total a per-method view hides" do
    complexity(FixtureHelper::COMPLEX_FILES) do |scores|
      rollup = scores.classes.first
      expect(rollup).to(have_attributes(name: "App::Knot::Tangle", cognitive: 12, method_count: 3, peak: 12))
    end
  end
  it "flags methods over the threshold as findings with a breakdown and advice" do
    complexity(FixtureHelper::COMPLEX_FILES) do |scores|
      finding = scores.findings.first
      expect(scores.findings.size).to(eq(1))
      expect(finding.kind).to(eq("complexity"))
      expect(finding.package).to(eq("App::Knot::Tangle#tangled"))
      expect(finding.message).to(include("cognitive 12, 4 calls", "guard clauses"))
      expect(finding.evidence).to(include("if +10 (lines 9, 10, 11, 12)", "boolean +2 (line 13)"))
    end
  end
  it "reports nothing when every method is under the threshold" do
    files = { "lib/app/tiny/x.rb" => "module App; module Tiny; class X; def a = 1; end; end; end\n" }
    complexity(files) do |scores|
      expect(scores.findings).to(be_empty)
    end
  end
end
