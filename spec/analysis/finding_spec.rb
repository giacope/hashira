# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Finding) do
  def effort = Hashira::Complexity::MethodFinding::Effort.new(cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if")

  def flattened = { cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if" }

  it "flattens a detail object into plain data and drops empty fields" do
    finding =
      described_class.new(kind: "complexity", package: "App#run", detail: effort, evidence: [], sources: ["a.rb"])
    expect(finding.to_h).to(
      eq(kind: "complexity", package: "App#run", evidence: [], sources: ["a.rb"], detail: flattened)
    )
  end

  it "omits the detail key entirely when a finding carries none" do
    finding = described_class.new(kind: "cycle", package: "app", evidence: [])
    expect(finding.to_h).to(eq(kind: "cycle", package: "app", evidence: [], sources: []))
  end

  it "records the files it names, without repeats" do
    finding = described_class.new(kind: "cycle", package: "app", evidence: [], sources: %w[a.rb b.rb a.rb])
    expect(finding.names?(["b.rb"])).to(be(true))
    expect(finding.names?(["c.rb"])).to(be(false))
  end
end
