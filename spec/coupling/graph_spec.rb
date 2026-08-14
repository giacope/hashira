# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Graph) do
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

  describe "#cycles.weakest" do
    it "picks the lightest edge along the path" do
      with_cycle do |graph|
        expect(graph.cycles.weakest(%w[alpha beta alpha])).to(eq(%w[alpha beta]))
      end
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

    it "reports the offending edges" do
      analyze(Fixtures::CYCLIC_FILES) do |_project, _census, graph|
        expect(graph.violations).to(eq([%w[beta alpha]]))
      end
    end
  end
end
