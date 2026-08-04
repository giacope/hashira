# frozen_string_literal: true

RSpec.describe(Hashira::CI::Gate) do
  def findings(all) = Hashira::CI::Accepted.new([]).screen(all)

  def finding(kind:, evidence:)
    Hashira::Analysis::Finding.new(
      kind:, package: "a", cycle: %w[a b a], evidence:,
      detail: { weak: %w[a b], weight: 1, from: "a", to: "b", from_instability: 0.0, to_instability: 1.0 }
    )
  end

  it "passes when no findings match the gated kinds" do
    other = finding(kind: "sdp_violation", evidence: [])
    io = StringIO.new
    expect(described_class.new(findings([other]), %w[cycle], io:).check).to(eq(0))
    expect(io.string).to(eq("Gate OK: no findings of kind cycle.\n"))
  end

  it "fails and prints matching findings with sampled evidence" do
    cycle = finding(kind: "cycle", evidence: %w[e1 e2 e3 e4 e5])
    io = StringIO.new
    expect(described_class.new(findings([cycle]), %w[cycle sdp_violation], io:).check).to(eq(1))
    expect(io.string).to(eq(<<~TEXT))
      cycle: a can reach itself: a -> b -> a — any change may ripple back around. The lightest edge on this cycle is a -> b (1 ref).
          · e1
          · e2
          · e3
          · e4

      Gate FAILED: 1 finding(s) of kind cycle, sdp_violation.
    TEXT
  end
end
