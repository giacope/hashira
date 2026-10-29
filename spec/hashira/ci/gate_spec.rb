# frozen_string_literal: true

RSpec.describe(Hashira::CI::Gate, :aggregate_failures) do
  def findings(all) = Hashira::CI::Accepted.new([]).screen(all)

  def gated(gate)
    gate.print
    gate.status
  end

  def detail(kind)
    return Hashira::Coupling::Imbalance::Gap.new("a", "b", 0.0, 1.0) if kind == "unstable_dependency"
    Hashira::Coupling::Cycle::Ring.new(%w[a b], [], Hashira::Coupling::Ties.new([["a", "b", 1]]), true)
  end

  def finding(kind:, evidence:)
    name = Hashira::Analysis::Finding::Name.new("a", [], [%w[a b a]])
    Hashira::Analysis::Finding.new(kind, name, detail(kind), Hashira::Analysis::Finding::Proof.new(evidence))
  end

  it "passes when no findings match the gated kinds" do
    other = finding(kind: "unstable_dependency", evidence: [])
    io = StringIO.new
    expect(gated(described_class.new(findings([other]), %w[cycle], io:))).to(eq(0))
    expect(io.string).to(eq("Gate OK: no findings of kind cycle.\n"))
  end

  it "fails and prints matching findings with sampled evidence" do
    cycle = finding(kind: "cycle", evidence: %w[e1 e2 e3 e4 e5])
    io = StringIO.new
    expect(gated(described_class.new(findings([cycle]), %w[cycle unstable_dependency], io:))).to(eq(1))
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
    expect(gated(described_class.new(findings(all), kinds, io:, error:))).to(eq(1))
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
