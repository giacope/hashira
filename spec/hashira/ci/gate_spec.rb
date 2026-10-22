# frozen_string_literal: true

RSpec.describe(Hashira::CI::Gate, :aggregate_failures) do
  def findings(all) = Hashira::CI::Accepted.new([]).screen(all)

  def finding(kind:, evidence:)
    Hashira::Analysis::Finding.new(
      kind:, package: "a", cycle: %w[a b a], evidence:,
      detail: {
        members: %w[a b], folded: [], cut: [{ from: "a", to: "b", weight: 1 }],
        from: "a", to: "b", from_instability: 0.0, to_instability: 1.0
      }
    )
  end

  it "passes when no findings match the gated kinds" do
    other = finding(kind: "unstable_dependency", evidence: [])
    io = StringIO.new
    expect(described_class.new(findings([other]), %w[cycle], io:).check).to(eq(0))
    expect(io.string).to(eq("Gate OK: no findings of kind cycle.\n"))
  end

  it "fails and prints matching findings with sampled evidence" do
    cycle = finding(kind: "cycle", evidence: %w[e1 e2 e3 e4 e5])
    io = StringIO.new
    expect(described_class.new(findings([cycle]), %w[cycle unstable_dependency], io:).check).to(eq(1))
    expect(io.string).to(eq(<<~TEXT))
      cycle: a and b depend on each other in a cycle — any change may ripple back around. The cheapest cut is a -> b (1 ref).
          · e1
          · e2
          · e3
          · e4

      Gate FAILED: 1 finding(s) — cycle 1.
    TEXT
  end

  it "names only the kinds that fired, worst first, and mirrors the verdict to stderr" do
    all = [finding(kind: "cycle", evidence: [])] + Array.new(2) { finding(kind: "nil_check", evidence: []) }
    io, error = Array.new(2) { StringIO.new }
    kinds = %w[cycle nil_check unstable_dependency utility_function]
    expect(described_class.new(findings(all), kinds, io:, error:).check).to(eq(1))
    expect([io.string, error.string]).to(
      match(
        [
          include("Gate FAILED: 3 finding(s) — nil_check 2, cycle 1.").and(exclude("unstable_dependency")),
          eq("Gate FAILED: 3 finding(s) — nil_check 2, cycle 1.\n")
        ]
      )
    )
  end
end
