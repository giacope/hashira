# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Scores) do
  it "ranks methods by cognitive complexity, worst first" do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      worst = scores.ranked.first
      expect(worst.subject).to(eq("App::Knot::Tangle#tangled"))
      expect(worst.cognitive).to(eq(12))
      expect(worst.calls).to(eq(4))
    end
  end

  it "labels instance methods with # and singleton methods with ." do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      subjects = scores.ranked.map(&:subject)
      expect(subjects).to(include("App::Knot::Tangle.helper", "App::Knot::Tangle#simple"))
    end
  end

  it "rolls complexity up per class — the total a per-method view hides" do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      rollup = scores.classes.first
      expect(rollup).to(have_attributes(name: "App::Knot::Tangle", cognitive: 12, method_count: 3, peak: 12))
    end
  end

  it "flags methods over the threshold as findings with a breakdown and advice" do
    complexity(Fixtures::COMPLEX_FILES) do |scores|
      finding = scores.findings.first
      expect(scores.findings.size).to(eq(1))
      expect(finding.kind).to(eq("complexity"))
      expect(finding.package).to(eq("App::Knot::Tangle#tangled"))
      expect(message(finding)).to(include("cognitive 12, 4 calls", "guard clauses"))
      expect(finding.evidence).to(include("if +10 (lines 9, 10, 11, 12)", "boolean +2 (line 13)"))
    end
  end

  it "flags a method from exactly the threshold, and not one point below it" do
    ten = "def ten\n if a\n  if b\n   if c\n    d if e\n   end\n  end\n end\nend\n"
    nine = "def nine\n x if p\n x if q\n x if r\n if a\n  if b\n   c if d\n  end\n end\nend\n"
    source = "module App; module Knot; class Edge\n#{ten}#{nine}end; end; end\n"
    complexity({ "lib/app/knot/edge.rb" => source }) do |scores|
      expect(scores.ranked.map(&:cognitive)).to(eq([10, 9]))
      expect(scores.findings.map(&:package)).to(eq(["App::Knot::Edge#ten"]))
    end
  end

  it "names the method's site and advises on the label that cost the most, not the first one seen" do
    run = "def run\n x unless a\n if b\n  if c\n   if d\n    e if f\n   end\n  end\n end\nend\n"
    source = "module App; module Knot; class Guard\n#{run}end; end; end\n"
    complexity({ "lib/app/knot/guard.rb" => source }) do |scores|
      text = message(scores.findings.first)
      expect(text).to(include("(knot/guard.rb:2)", "flatten the branching"))
      expect(text).not_to(include("invert to a guard clause"))
    end
  end

  it "scores methods wherever the class body declares them, not only its top-level defs" do
    source = <<~RUBY
      module App
        module Hidden
          class Box
            private def tucked = a ? b : c
            protected(def guarded = a ? b : c)
            class << self
              def opened = a ? b : c
            end
            class << other
              def elsewhere = a ? b : c
            end
            if ENV["X"]
              def conditional = a ? b : c
            end
            Row = Data.define(:x) do
              def row = a ? b : c
            end
            configure do
              def blocked = a ? b : c
            end
            configure(&setup)
          end
          class Empty; end
          module Concern
            class_methods do
              def lifted = a ? b : c
            end
          end
        end
      end
    RUBY
    complexity({ "lib/app/hidden/box.rb" => source }) do |scores|
      expect(scores.ranked.map(&:subject)).to(
        contain_exactly(
          "App::Hidden::Box#tucked", "App::Hidden::Box#guarded", "App::Hidden::Box.opened",
          "App::Hidden::Box#conditional", "App::Hidden::Box::Row#row", "App::Hidden::Box#blocked",
          "App::Hidden::Concern.lifted"
        )
      )
    end
  end

  it "leaves a nested class's methods to that class, so none is scored twice" do
    source = "module App; module Nest; class Outer\nclass << self\nclass Inner; def deep = 1; end\nend\nend; end; end\n"
    complexity({ "lib/app/nest/outer.rb" => source }) do |scores|
      expect(scores.ranked.map(&:subject)).to(eq(["App::Nest::Outer::Inner#deep"]))
    end
  end

  it "reports nothing when every method is under the threshold" do
    files = { "lib/app/tiny/x.rb" => "module App; module Tiny; class X; def a = 1; end; end; end\n" }
    complexity(files) do |scores|
      expect(scores.findings).to(be_empty)
    end
  end
end
