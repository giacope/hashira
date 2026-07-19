# frozen_string_literal: true

RSpec.describe Hashira::CI::Gate do
  def findings(all) = Hashira::CI::Accepted.new([]).screen(all)

  def finding(kind:, message:, evidence:)
    Hashira::Analysis::Finding.new(kind:, package: "p", message:, evidence:)
  end

  it "passes when no findings match the gated kinds" do
    other = finding(kind: "sdp_violation", message: "m", evidence: [])
    io = StringIO.new
    expect(described_class.new(findings([other]), %w[cycle], io:).check).to eq(0)
    expect(io.string).to eq("Gate OK: no findings of kind cycle.\n")
  end

  it "fails and prints matching findings with sampled evidence" do
    cycle = finding(kind: "cycle", message: "a cycles",
                    evidence: %w[e1 e2 e3 e4 e5])
    io = StringIO.new
    expect(described_class.new(findings([cycle]), %w[cycle sdp_violation], io:).check).to eq(1)
    expect(io.string).to eq(<<~TEXT)
      cycle: a cycles
          · e1
          · e2
          · e3
          · e4

      Gate FAILED: 1 finding(s) of kind cycle, sdp_violation.
    TEXT
  end
end
