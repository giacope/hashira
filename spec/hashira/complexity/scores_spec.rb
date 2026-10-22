# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Scores, :aggregate_failures) do
  def ranked(files) = complexity(files, &:ranked)

  def flagged(files) = complexity(files, &:findings)

  it "ranks methods by cognitive complexity, worst first" do
    worst = ranked(Fixtures::COMPLEX_FILES).first
    expect([worst.subject, worst.cognitive, worst.calls]).to(eq(["App::Knot::Tangle#tangled", 12, 4]))
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
    findings = flagged(Fixtures::COMPLEX_FILES)
    expect(findings.map { [it.kind, it.package] }).to(eq([["complexity", "App::Knot::Tangle#tangled"]]))
    expect(message(findings.first)).to(include("cognitive 12, 4 calls", "guard clauses"))
    expect(findings.first.evidence).to(include("if +10 (lines 9, 10, 11, 12)", "boolean +2 (line 13)"))
  end

  it "flags a method from exactly the threshold, and not one point below it" do
    ten = "def ten\n if a\n  if b\n   if c\n    d if e\n   end\n  end\n end\nend\n"
    nine = "def nine\n x if p\n x if q\n x if r\n if a\n  if b\n   c if d\n  end\n end\nend\n"
    files = { "lib/app/knot/edge.rb" => "module App; module Knot; class Edge\n#{ten}#{nine}end; end; end\n" }
    expect([ranked(files).map(&:cognitive), flagged(files).map(&:package)]).to(eq([[10, 9], ["App::Knot::Edge#ten"]]))
  end

  it "names the method's site and advises on the label that cost the most, not the first one seen" do
    run = "def run\n x unless a\n if b\n  if c\n   if d\n    e if f\n   end\n  end\n end\nend\n"
    source = "module App; module Knot; class Guard\n#{run}end; end; end\n"
    expect(message(flagged({ "lib/app/knot/guard.rb" => source }).first)).to(
      include("(knot/guard.rb:2)", "flatten the branching").and(exclude("invert to a guard clause"))
    )
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

  it "charges each method of a recursion cycle one point, direct or through a sibling" do
    files = {
      "lib/app/walk.rb" => <<~RUBY
        class Walk
          def fact(n) = n <= 1 ? 1 : n * fact(n - 1)
          def even?(n) = n.zero? || odd?(n - 1)
          def odd?(n) = !n.zero? && even?(n - 1)
          def tree(node) = node.children.each { self.tree(it) }
          def self.count(n) = n.zero? ? 0 : count(n - 1)
          def name(user) = user.name
          def plain = helper
          def helper
            def inner = plain
            1
          end
          def empty; end
        end
      RUBY
    }
    scores = ranked(files)
    expect(scores.to_h { [it.subject, it.cognitive] }).to(
      include(
        "Walk#fact" => 2, "Walk#even?" => 2, "Walk#odd?" => 2, "Walk#tree" => 1,
        "Walk.count" => 2, "Walk#name" => 0, "Walk#plain" => 0, "Walk#empty" => 0
      )
    )
    expect(scores.find { it.subject == "Walk#fact" }.increments.map(&:label))
      .to(contain_exactly("ternary", "recursion"))
  end

  it "advises on a recursion when it is what costs the most" do
    score = ranked({ "lib/app/walk.rb" => "class Walk\n  def go(n) = go(n - 1)\nend\n" }).first
    finding = Hashira::Complexity::MethodFinding.new(score.with(cognitive: 10)).to_finding
    expect(message(finding)).to(include("name the traversal"))
  end

  it "scores a method defined with define_method under its own name" do
    files = {
      "lib/app/dyn.rb" => <<~RUBY
        class Dyn
          define_method(:run) { |a| a ? 1 : 2 }
          define_method("walk") do |a|
            if a then 1 end
          end
          %i[x y].each { |name| define_method(name) { name if name } }
          define_method { 1 }
          self.define_method(:ignored) { 1 }
          define_method(:lazy, instance_method(:run))
        end
      RUBY
    }
    expect(ranked(files).to_h { [it.subject, it.cognitive] }).to(
      eq("Dyn#run" => 1, "Dyn#walk" => 1, "Dyn#define_method(name)" => 1)
    )
  end
end
