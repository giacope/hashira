# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, "#findings") do
  def verdicts(files, directories: ["lib/app"])
    within(files) do
      yield(Hashira::Pipeline.new(Hashira::Project.new(directories)).findings)
    end
  end
  it "reports cycles with path, weakest edge, and evidence" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map(&:package)).to(eq(%w[alpha]))
      finding = cycles.first
      expect(finding.cycle).to(eq(%w[alpha beta alpha]))
      expect(message(finding)).to(include("alpha can reach itself: alpha -> beta -> alpha"))
      expect(message(finding)).to(include("The lightest edge on this cycle is alpha -> beta (1 ref)."))
      expect(finding.evidence).to(include("alpha/one.rb:4: Beta::Two"))
    end
  end

  it "reports each distinct loop once, from its smallest member" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.size).to(eq(1))
      expect(cycles.first.package).to(eq("alpha"))
    end
  end

  it "pluralizes a multi-ref weakest edge" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = [A::X, A::Y]; end; end; end\n"
    }
    verdicts(files) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(include("(2 refs)."))
    end
  end

  it "reports SDP violations with instabilities and evidence" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      violations = all.select { it.kind == "sdp_violation" }
      expect(violations.size).to(eq(1))
      finding = violations.first
      expect(finding.package).to(eq("beta"))
      expect(message(finding)).to(include("beta (I=0.50) depends on the LESS stable alpha (I=0.67)"))
      expect(finding.evidence).to(include("beta/two.rb:4: Alpha::One"))
    end
  end

  it "reports a package whose clients split into audiences, naming the seam" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; def a = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; def a = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" => "module App; module One; class A; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/two/b.rb" => "module App; module Two; class B; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [App::Core::Graph, Core::Chart, Core::Score]; end; end; end\n" # rubocop:disable Layout/LineLength
    }
    message =
      "core splits 2 ways: main, one, three, two share Core::Score, Core::Walk; " \
        "main alone uses Core::Chart, Core::Graph — " \
        "parts with separate client bases are separate packages in disguise. " \
        "Split core along that seam, keeping the shared constants as the base layer the rest builds on."
    verdicts(files) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(finding.package).to(eq("core"))
      expect(message(finding)).to(eq(message))
      expect(finding.evidence).to(include("main/d.rb:1: App::Core::Graph"))
      expect(finding.evidence.size).to(eq(4))
    end
  end

  it "reports disjoint audiences without a shared base layer" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; def a = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; def a = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" => "module App; module One; class A; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/two/b.rb" => "module App; module Two; class B; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Graph, Core::Chart]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [Core::Graph, Core::Chart]; end; end; end\n"
    }
    message =
      "core splits 2 ways: main, three use Core::Chart, Core::Graph; " \
        "one, two use Core::Score, Core::Walk — " \
        "parts with separate client bases are separate packages in disguise. " \
        "Split core along that seam."
    verdicts(files) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(message(finding)).to(eq(message))
    end
  end

  it "reports an edge too wide for one interface" do
    files = {
      "lib/app/core/a.rb" => "module App; module Core; class A; def a = 1; end; end; end\n",
      "lib/app/core/b.rb" => "module App; module Core; class B; def a = 1; end; end; end\n",
      "lib/app/core/c.rb" => "module App; module Core; class C; def a = 1; end; end; end\n",
      "lib/app/core/d.rb" => "module App; module Core; class D; def a = 1; end; end; end\n",
      "lib/app/core/e.rb" => "module App; module Core; class E; def a = 1; end; end; end\n",
      "lib/app/main/uses.rb" =>
        "module App; module Main; class Uses; def go = [Core::A, Core::B, Core::C, Core::D, Core::E]; end; end; end\n"
    }
    expected =
      "main -> core is 5 constants wide (Core::A, Core::B, Core::C, Core::D, Core::E) — " \
        "every one is a reason for main to change. Front core with one facade."
    verdicts(files) do |all|
      finding = all.find { it.kind == "wide_edge" }
      expect(finding.package).to(eq("main"))
      expect(finding.digest).to(eq("main -> core"))
      expect(message(finding)).to(eq(expected))
      expect(finding.evidence.size).to(eq(4))
    end
  end

  it "reports a roll-call of words kept in sync across packages" do
    files = {
      "lib/app/one/a.rb" => "module One; class A; KINDS = %w[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/two/b.rb" => "module Two; class B; KINDS = %i[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/three/c.rb" =>
        "module App; module Three; class C; MAP = { \"red\" => 1, blue: 2, lime: 3 }; def a = MAP; end; end; end\n"
    }
    expected =
      "the words blue, lime, red are listed together in one/a.rb, three/c.rb, two/b.rb — " \
        "3 packages keep one roll-call in sync by hand. Make the list data with a single owner."
    verdicts(files) do |all|
      finding = all.find { it.kind == "roll_call" }
      expect(finding.digest).to(eq("blue,lime,red"))
      expect(message(finding)).to(eq(expected))
      expect(finding.evidence).to(eq(["one/a.rb", "three/c.rb", "two/b.rb"]))
    end
  end

  it "lists findings in rule order" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      expect(all.map(&:kind).uniq).to(eq(%w[cycle sdp_violation utility_function]))
    end
  end
end
