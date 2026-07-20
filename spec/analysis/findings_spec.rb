# frozen_string_literal: true

RSpec.describe Hashira::Pipeline, "#findings" do
  def findings_for(files, directories: ["lib/app"])
    within_project(files) do
      yield Hashira::Pipeline.new(Hashira::Project.new(directories)).findings
    end
  end

  it "reports cycles with path, weakest edge, and evidence" do
    findings_for(FixtureHelper::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map(&:package)).to eq(%w[alpha beta])
      finding = cycles.first
      expect(finding.cycle).to eq(%w[alpha beta alpha])
      expect(finding.message).to include("alpha can reach itself: alpha -> beta -> alpha")
      expect(finding.message).to include("The lightest edge on this cycle is alpha -> beta (1 ref).")
      expect(finding.evidence).to include("alpha/one.rb:4: Beta::Two")
    end
  end

  it "pluralizes the weakest-edge ref count" do
    findings_for(FixtureHelper::CYCLIC_FILES) do |all|
      beta_cycle = all.find { it.kind == "cycle" && it.package == "beta" }
      expect(beta_cycle.message).to include("(1 ref).")
    end
  end

  it "pluralizes a multi-ref weakest edge" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = [A::X, A::Y]; end; end; end\n"
    }
    findings_for(files) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(cycle.message).to include("(2 refs).")
    end
  end

  it "reports SDP violations with instabilities and evidence" do
    findings_for(FixtureHelper::CYCLIC_FILES) do |all|
      violations = all.select { it.kind == "sdp_violation" }
      expect(violations.size).to eq(1)
      finding = violations.first
      expect(finding.package).to eq("beta")
      expect(finding.message).to include("beta (I=0.50) depends on the LESS stable alpha (I=0.67)")
      expect(finding.evidence).to include("beta/two.rb:4: Alpha::One")
    end
  end

  it "lists findings in rule order" do
    findings_for(FixtureHelper::CYCLIC_FILES) do |all|
      expect(all.map(&:kind).uniq).to eq(%w[cycle sdp_violation])
    end
  end
end
