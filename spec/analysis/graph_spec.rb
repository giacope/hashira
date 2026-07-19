# frozen_string_literal: true

RSpec.describe Hashira::Analysis::Graph do
  def with_cyclic_graph(&)
    analyze(FixtureHelper::CYCLIC_FILES) { |_project, _census, graph| yield(graph) }
  end

  it "builds edges from constant references, skipping self-references" do
    with_cyclic_graph do |graph|
      expect(graph.edge_list.map(&:to_s)).to eq(["alpha -> beta", "alpha -> core", "beta -> alpha"])
    end
  end

  it "does not count the defined class itself as a reference" do
    files = {
      "lib/app/alpha/one.rb" => "module App; module Alpha; class One; def a = 1; end; end; end\n",
      "lib/app/beta/one.rb" => "module App; module Beta; class One; def a = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edge_list).to be_empty
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
      expect(graph.edge_list).to be_empty
      expect(graph.evidence_for("alpha", "alpha")).to be_empty
    end
  end

  it "records superclass references" do
    files = {
      "lib/app/alpha/base.rb" => "module App; module Alpha; class Base; def a = 1; end; end; end\n",
      "lib/app/beta/child.rb" => "module App; module Beta; class Child < Alpha::Base; def b = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edge_list.map(&:to_s)).to eq(["beta -> alpha"])
    end
  end

  describe "#dependencies_of / #dependents_of" do
    it "returns sorted package lists" do
      with_cyclic_graph do |graph|
        expect(graph.dependencies_of("alpha")).to eq(%w[beta core])
        expect(graph.dependents_of("alpha")).to eq(%w[beta])
        expect(graph.dependents_of("core")).to eq(%w[alpha])
        expect(graph.dependencies_of("core")).to eq([])
      end
    end
  end

  describe "#metric_for" do
    it "computes Ca, Ce, instability, and type count" do
      with_cyclic_graph do |graph|
        expect(graph.metric_for("alpha").to_h).to eq(tc: 1, ca: 1, ce: 2, i: 2.0 / 3)
        expect(graph.metric_for("core").to_h).to eq(tc: 1, ca: 1, ce: 0, i: 0.0)
      end
    end

    it "gives instability 0.0 to an unconnected package" do
      files = { "lib/app/solo/x.rb" => "module App; module Solo; class X; def a = 1; end; end; end\n" }
      analyze(files) do |_project, _census, graph|
        expect(graph.metric_for("solo").to_h).to eq(tc: 1, ca: 0, ce: 0, i: 0.0)
      end
    end
  end

  describe "#metrics" do
    it "maps every package to its metric" do
      with_cyclic_graph do |graph|
        expect(graph.metrics.keys).to contain_exactly("alpha", "beta", "core")
        expect(graph.metrics["beta"]).to eq(graph.metric_for("beta"))
      end
    end
  end

  describe "#cyclic?" do
    it "is true only for packages that can reach themselves" do
      with_cyclic_graph do |graph|
        expect(graph.cyclic?("alpha")).to be(true)
        expect(graph.cyclic?("beta")).to be(true)
        expect(graph.cyclic?("core")).to be(false)
      end
    end
  end

  describe "#weight and #evidence" do
    it "counts distinct references backing an edge" do
      with_cyclic_graph do |graph|
        expect(graph.weight("beta", "alpha")).to eq(2)
        expect(graph.weight("alpha", "core")).to eq(1)
        expect(graph.evidence_for("alpha", "core").to_a).to eq(["alpha/one.rb:5: Core::Util"])
        expect(graph.evidence_for("beta", "alpha").to_a)
          .to contain_exactly("beta/two.rb:4: Alpha::One", "beta/two.rb:5: App::Alpha::One")
      end
    end
  end

  describe "#cycle_path" do
    it "returns the shortest path back to the package" do
      with_cyclic_graph do |graph|
        expect(graph.cycle_path("alpha")).to eq(%w[alpha beta alpha])
        expect(graph.cycle_path("core")).to be_nil
      end
    end

    it "prefers the shortest cycle over a longer alternative route" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, C::X]; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n",
        "lib/app/c/x.rb" => "module App; module C; class X; def c = B::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.cycle_path("a")).to eq(%w[a b a])
      end
    end

    it "traverses longer cycles" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = C::X; end; end; end\n",
        "lib/app/c/x.rb" => "module App; module C; class X; def c = A::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.cycle_path("a")).to eq(%w[a b c a])
      end
    end
  end

  describe "#weakest_edge" do
    it "picks the lightest edge along the path" do
      with_cyclic_graph do |graph|
        expect(graph.weakest_edge(%w[alpha beta alpha])).to eq(%w[alpha beta])
      end
    end
  end

  describe "#sdp_violations" do
    it "flags edges pointing at less stable packages" do
      files = {
        "lib/app/hub/x.rb" => "module App; module Hub; class X; def c = Volatile::X; end; end; end\n",
        "lib/app/volatile/x.rb" => "module App; module Volatile; class X; def c = [Leaf::X, Leaf::Y]; end; end; end\n",
        "lib/app/leaf/x.rb" => "module App; module Leaf; class X; def a = 1; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.sdp_violations).to be_empty
      end
    end

    it "does not flag edges between equally stable packages" do
      files = {
        "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n"
      }
      analyze(files) do |_project, _census, graph|
        expect(graph.sdp_violations).to be_empty
      end
    end

    it "reports the offending edges" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, _census, graph|
        expect(graph.sdp_violations).to eq([%w[beta alpha]])
      end
    end
  end
end
