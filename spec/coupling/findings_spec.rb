# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, "#findings") do
  def ring(size, extra)
    (1..size).to_h do |n|
      uses = "[C#{(n % size) + 1}::X, #{extra}]"
      ["lib/app/c#{n}/x.rb", "module App; module C#{n}; class X; def c = #{uses}; end; end; end\n"]
    end
  end

  def verdicts(files, directories: ["lib/app"])
    within(files) do
      yield(Hashira::Pipeline.new(Hashira::Project.new(directories)).findings)
    end
  end
  it "reports cycles with members, a sample path, the cheapest cut, and its evidence" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map(&:package)).to(eq(%w[alpha]))
      finding = cycles.first
      expect(finding.cycle).to(eq(%w[alpha beta alpha]))
      expect(message(finding)).to(include("alpha and beta depend on each other in a cycle"))
      expect(message(finding)).to(include("The cheapest cut is alpha -> beta (1 ref)."))
      expect(finding.evidence).to(eq(["alpha/one.rb:4: Beta::Two"]))
    end
  end

  it "reports each distinct loop once, from its smallest member" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.size).to(eq(1))
      expect(cycles.first.package).to(eq("alpha"))
    end
  end

  it "reports every distinct loop, one finding each" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n",
      "lib/app/c/x.rb" => "module App; module C; class X; def c = D::X; end; end; end\n",
      "lib/app/d/x.rb" => "module App; module D; class X; def c = C::X; end; end; end\n"
    }
    verdicts(files) do |all|
      expect(all.select { it.kind == "cycle" }.map(&:cycle)).to(eq([%w[a b a], %w[c d c]]))
    end
  end

  it "names the cheapest cut wherever it sits on the cycle" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n"
    }
    verdicts(files) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(include("The cheapest cut is b -> a (1 ref)."))
    end
  end

  it "reports a knot of packages once, from its smallest member, whatever loops run through it" do
    verdicts(ring(8, "C1::X")) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map { [it.package, it.detail[:members].size] }).to(eq([["c1", 8]]))
      expect(message(cycles.first)).to(start_with("c1, c2, c3, c4, c5, c6 and 2 more depend on each other in a cycle"))
    end
  end

  it "lists a three-package knot in full" do
    verdicts(ring(3, "nil")) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(start_with("c1, c2 and c3 depend on each other in a cycle"))
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
      "lib/app/main/d.rb" => "module App; module Main; class D; " \
        "def c = [App::Core::Graph, Core::Chart, Core::Score]; end; end; end\n"
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

  it "backs an audience with evidence when its clients reach only nested constants" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; LIMIT = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; LIMIT = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" =>
        "module App; module One; class A; def c = [Core::Walk::LIMIT, Core::Score::LIMIT]; end; end; end\n",
      "lib/app/two/b.rb" =>
        "module App; module Two; class B; def c = [Core::Walk::LIMIT, Core::Score::LIMIT]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Graph, Core::Chart]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [Core::Graph, Core::Chart]; end; end; end\n"
    }
    verdicts(files) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(finding.evidence).to(
        eq(["main/d.rb:1: Core::Graph", "main/d.rb:1: Core::Chart", "one/a.rb:1: Core::Walk::LIMIT", "one/a.rb:1: Core::Score::LIMIT"])
      )
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

  it "leaves the presentation layer's edge into the domain it exposes out of wide edges" do
    billing = %w[A B C D E].to_h do |name|
      ["app/models/billing/#{name.downcase}.rb", "module Billing\n  class #{name}\n    def x = 1\n  end\nend\n"]
    end
    reach = "[Billing::A, Billing::B, Billing::C, Billing::D, Billing::E]"
    files = billing.merge(
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/order.rb" => "class Order\n  def bill = #{reach}\nend\n",
      "app/controllers/bills_controller.rb" => "class BillsController\n  def index = #{reach}\nend\n"
    )
    verdicts(files, directories: ["app"]) do |all|
      expect(all.select { it.kind == "wide_edge" }.map(&:digest)).to(eq(["Order -> Billing"]))
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
