# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Finding) do
  it "flattens a detail object into plain data and drops empty fields" do
    effort = Hashira::Complexity::MethodFinding::Effort.new(cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if")
    finding = described_class.new(kind: "complexity", package: "App#run", detail: effort, evidence: [])
    flattened = { cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if" }
    expect(finding.to_h).to(eq(kind: "complexity", package: "App#run", evidence: [], detail: flattened))
  end

  it "traces by evidence where there is some, and by the shape of the code it names where there is none" do
    base = { kind: "nil_check", package: "A#b", shape: "abc", detail: { site: "a.rb:2" } }
    traced = ->(evidence) { described_class.new(**base, evidence:).trace }
    expect([traced[["x (line 3)"]], traced[[]]]).to(eq(["nil_check|a.rb|x", "nil_check|a.rb|abc"]))
  end

  it "keeps the shape out of the machine format, since only the ratchet reads it" do
    finding = described_class.new(kind: "nil_check", package: "A#b", evidence: [], shape: "abc")
    expect(finding.to_h).to(eq(kind: "nil_check", package: "A#b", evidence: []))
  end

  it "omits the detail key entirely when a finding carries none" do
    finding = described_class.new(kind: "cycle", package: "app", evidence: [])
    expect(finding.to_h).to(eq(kind: "cycle", package: "app", evidence: []))
  end
end
