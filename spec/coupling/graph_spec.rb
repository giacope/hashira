# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Graph) do
  def source(name, uses)
    refs = uses.each_with_index.map { |other, index| "#{other.capitalize}::X#{index}" }.join(", ")
    "module App; module #{name.capitalize}; class X; def c = [#{refs}]; end; end; end\n"
  end

  def with_cycle(&)
    analyze(Fixtures::CYCLIC_FILES) { |_project, _census, graph| yield(graph) }
  end

  it "builds edges from constant references, skipping self-references" do
    with_cycle do |graph|
      expect(graph.edges.map(&:to_s)).to(eq(["alpha -> beta", "alpha -> core", "beta -> alpha"]))
    end
  end

  it "does not count the defined class itself as a reference" do
    files = {
      "lib/app/alpha/one.rb" => "module App; module Alpha; class One; def a = 1; end; end; end\n",
      "lib/app/beta/one.rb" => "module App; module Beta; class One; def a = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "ignores external and same-package references entirely" do
    files = {
      "lib/app/alpha/one.rb" => <<~RUBY,
        module App
          module Alpha
            class One
              def a = JSON
              def b = Alpha::Two
            end
          end
        end
      RUBY
      "lib/app/alpha/two.rb" => "module App; module Alpha; class Two; def a = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
      expect(graph.evidence("alpha", "alpha")).to(be_empty)
    end
  end

  it "records superclass references" do
    files = {
      "lib/app/alpha/base.rb" => "module App; module Alpha; class Base; def a = 1; end; end; end\n",
      "lib/app/beta/child.rb" => "module App; module Beta; class Child < Alpha::Base; def b = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["beta -> alpha"]))
    end
  end

  describe "#usage" do
    it "records which of a package's constants each client touches" do
      with_cycle do |graph|
        expect(graph.usage("core")).to(eq("alpha" => Set["Core::Util"]))
        expect(graph.usage("alpha")).to(eq("beta" => Set["Alpha::One"]))
      end
    end

    it "credits a reference to a type's constant or unknown member to the type that holds it" do
      files = {
        "lib/app/core/util.rb" => "module App; module Core; class Util; LIMIT = 1; def self.help = 1; end; end; end\n",
        "lib/app/main/uses.rb" => <<~RUBY
          module App; module Main; class Uses
            def go = [Core::Util::LIMIT, Core::Util::Missing, Core::Util]
          end; end; end
        RUBY
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.usage("core")).to(eq("main" => Set["Core::Util"]))
      end
    end
  end

  describe "#outgoing / #incoming" do
    it "returns sorted package lists" do
      with_cycle do |graph|
        expect(graph.outgoing("alpha")).to(eq(%w[beta core]))
        expect(graph.incoming("alpha")).to(eq(%w[beta]))
        expect(graph.incoming("core")).to(eq(%w[alpha]))
        expect(graph.outgoing("core")).to(eq([]))
      end
    end
  end

  describe "#metric" do
    it "computes Ca, Ce, instability, and type count" do
      with_cycle do |graph|
        expect(graph.metric("alpha").to_h).to(eq(tc: 1, ca: 1, ce: 2, i: 2.0 / 3))
        expect(graph.metric("core").to_h).to(eq(tc: 1, ca: 1, ce: 0, i: 0.0))
      end
    end

    it "leaves instability unset for an unconnected package, rather than calling it maximally stable" do
      files = { "lib/app/solo/x.rb" => "module App; module Solo; class X; def a = 1; end; end; end\n" }
      analyze(files) do |_project, _census, graph|
        expect(graph.metric("solo").to_h).to(eq(tc: 1, ca: 0, ce: 0, i: nil))
        expect(graph.metric("solo")).to(be_isolated)
        expect(graph.metric("solo").cells).to(eq([1, 0, 0, "—"]))
      end
    end
  end

  describe "#metrics" do
    it "maps every package to its metric" do
      with_cycle do |graph|
        expect(graph.metrics.keys).to(contain_exactly("alpha", "beta", "core"))
        expect(graph.metrics["beta"]).to(eq(graph.metric("beta")))
      end
    end

    it "orders connected packages from stable to unstable, and unconnected ones after them all" do
      files = Fixtures::CYCLIC_FILES.merge(
        "lib/app/solo/x.rb" => "module App; module Solo; class X; def a = 1; end; end; end\n"
      )
      analyze(files) do |_project, _census, graph|
        ranked = graph.metrics.sort_by { |_package, metric| metric.order }.map(&:first)
        expect(ranked).to(eq(%w[core beta alpha solo]))
      end
    end
  end

  describe "#cycles.through?" do
    it "is true only for packages that can reach themselves" do
      with_cycle do |graph|
        expect(graph.cycles.through?("alpha")).to(be(true))
        expect(graph.cycles.through?("beta")).to(be(true))
        expect(graph.cycles.through?("core")).to(be(false))
      end
    end
  end

  describe "#weight and #evidence" do
    it "counts distinct references backing an edge" do
      with_cycle do |graph|
        expect(graph.weight("beta", "alpha")).to(eq(2))
        expect(graph.weight("alpha", "core")).to(eq(1))
        expect(graph.evidence("alpha", "core").to_a).to(eq(["alpha/one.rb:5: Core::Util"]))
        expect(graph.evidence("beta", "alpha").to_a)
          .to(contain_exactly("beta/two.rb:4: Alpha::One", "beta/two.rb:5: App::Alpha::One"))
      end
    end
  end

  describe "#cycles.path" do
    it "returns the shortest path back to the package" do
      with_cycle do |graph|
        expect(graph.cycles.path("alpha")).to(eq(%w[alpha beta alpha]))
        expect(graph.cycles.path("core")).to(be_nil)
      end
    end

    it "prefers the shortest cycle over a longer alternative route" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, C::X]; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n",
        "lib/app/c/x.rb" => "module App; module C; class X; def c = B::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.cycles.path("a")).to(eq(%w[a b a]))
      end
    end

    it "traverses longer cycles" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = C::X; end; end; end\n",
        "lib/app/c/x.rb" => "module App; module C; class X; def c = A::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.cycles.path("a")).to(eq(%w[a b c a]))
      end
    end
  end

  describe "#cycles.knots" do
    it "groups the packages that can reach one another, one knot each" do
      uses = { "a" => %w[b], "b" => %w[a c], "c" => %w[d], "d" => %w[c e], "e" => [] }
      analyze(uses.to_h { |name, list| ["lib/app/#{name}/x.rb", source(name, list)] }) do |_project, _census, graph|
        expect(graph.cycles.knots).to(eq([%w[a b], %w[c d]]))
      end
    end

    it "finds a ring as one knot, whichever member it starts from" do
      uses = { "a" => [], "b" => %w[d], "c" => %w[b], "d" => %w[c] }
      analyze(uses.to_h { |name, list| ["lib/app/#{name}/x.rb", source(name, list)] }) do |_project, _census, graph|
        expect(graph.cycles.knots).to(eq([%w[b c d]]))
      end
    end
  end

  describe "#cycles.cut" do
    def cut(uses)
      analyze(uses.to_h { |name, list| ["lib/app/#{name}/x.rb", source(name, list)] }) do |_project, _census, graph|
        members = graph.cycles.knots.first
        yield(graph.cycles.cut(members))
      end
    end

    it "cuts the thin link between two heavy clusters" do
      uses = { "a" => %w[b b], "b" => %w[a a c], "c" => %w[d d], "d" => %w[c c a] }
      cut(uses) { expect(it).to(eq([["b", "c", 1]])) }
    end

    it "gives back an edge the cut turned out not to need" do
      uses = { "a" => %w[b c c c], "b" => %w[c c c], "c" => %w[a a] }
      cut(uses) { expect(it).to(eq([["c", "a", 2]])) }
    end

    it "breaks a small knot outright, leaving no loop behind" do
      uses = { "a" => %w[b b c], "b" => %w[c c], "c" => %w[a a] }
      cut(uses) { expect(it).to(eq([["a", "c", 1], ["a", "b", 2]])) }
    end

    it "does not count detaching one leaf as a cut" do
      uses = { "a" => %w[b b], "b" => %w[a a c c], "c" => %w[b b d], "d" => %w[a] }
      cut(uses) { expect(it).to(eq([["a", "b", 2]])) }
    end
  end

  describe "#violations" do
    it "flags edges pointing at less stable packages" do
      files = {
        "lib/app/hub/x.rb" => "module App; module Hub; class X; def c = Volatile::X; end; end; end\n",
        "lib/app/volatile/x.rb" => "module App; module Volatile; class X; def c = [Leaf::X, Leaf::Y]; end; end; end\n",
        "lib/app/leaf/x.rb" => "module App; module Leaf; class X; def a = 1; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.violations).to(be_empty)
      end
    end

    it "does not flag edges between equally stable packages" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.violations).to(be_empty)
      end
    end

    it "does not flag a dependency whose instability matches at the precision it is shown" do
      uses = { "a" => %w[b x1 x2], "b" => %w[y1 y2 y3 y4 y5] }
      uses.merge!(%w[p1 p2 p3 p4 p5].to_h { [it, %w[a]] }, %w[q1 q2 q3 q4 q5 q6 q7].to_h { [it, %w[b]] })
      files = (uses.keys | uses.values.flatten).to_h { ["lib/app/#{it}/x.rb", source(it, uses.fetch(it, []))] }
      analyze(files) do |_project, _census, graph|
        a, b = graph.metrics.values_at("a", "b")
        expect([a.instability < b.instability, a.shown, b.shown, graph.violations]).to(eq([true, "0.38", "0.38", []]))
      end
    end

    it "does not flag an edge whose ends share a cycle" do
      uses = { "a" => %w[b], "b" => %w[a p q], "c1" => %w[a], "c2" => %w[a], "p" => [], "q" => [] }
      analyze(uses.to_h { |name, list| ["lib/app/#{name}/x.rb", source(name, list)] }) do |_project, _census, graph|
        expect([graph.metric("a").level, graph.metric("b").level, graph.violations]).to(eq([0.25, 0.75, []]))
      end
    end

    it "flags an edge leaving a cycle" do
      files = Fixtures::UNSTABLE_FILES.merge(
        "lib/app/stock/x.rb" => "module App; module Stock; class X; def c = [Pricing::X, Depot::X]; end; end; end\n",
        "lib/app/depot/x.rb" => "module App; module Depot; class X; def c = Stock::X; end; end; end\n"
      )
      analyze(files) do |_project, _census, graph|
        expect(graph.violations).to(eq([%w[stock pricing]]))
      end
    end

    it "reports the offending edges" do
      analyze(Fixtures::UNSTABLE_FILES) do |_project, _census, graph|
        expect(graph.violations).to(eq([%w[stock pricing]]))
      end
    end
  end
end
