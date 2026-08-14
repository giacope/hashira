# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Finding) do
  it "flattens a detail object into plain data and drops empty fields" do
    effort = Hashira::Complexity::MethodFinding::Effort.new(cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if")
    finding = described_class.new(kind: "complexity", package: "App#run", detail: effort, evidence: [])
    flattened = { cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if" }
    expect(finding.to_h).to(eq(kind: "complexity", package: "App#run", evidence: [], detail: flattened))
  end

  it "omits the detail key entirely when a finding carries none" do
    finding = described_class.new(kind: "cycle", package: "app", evidence: [])
    expect(finding.to_h).to(eq(kind: "cycle", package: "app", evidence: []))
  end
end
