# frozen_string_literal: true

RSpec.describe(Hashira::CI::Ratchet, :aggregate_failures) do
  around { |example| within(Fixtures::CYCLIC_FILES) { example.run } }

  let(:graph) { pipeline(["lib/app"]).last }

  def finding(kind, package, digest: nil)
    Hashira::Analysis::Finding.new(kind:, package:, digest:, evidence: ["a.rb:1"], detail: detail(kind))
  end

  def detail(kind)
    return Hashira::Complexity::Trail::Trace.new(site: "a.rb:1", chain: 2) if kind == "indirection"
    Hashira::Duplication::DuplicationFinding::Overlap.new(size: 2, mass: 30, kind: :identical, hot: false)
  end

  def scored(kind, package, value)
    Hashira::Analysis::Finding.new(
      kind:, package:, evidence: ["a.rb:1"],
      detail: Hashira::Complexity::MethodFinding::Effort.new(cognitive: value, calls: 3, site: "a.rb:1", dominant: "if")
    )
  end

  def smell(kind, package, shape: nil)
    Hashira::Analysis::Finding.new(kind:, package:, evidence: [], detail: { site: "a.rb:1" }, shape:)
  end

  def ratchet(findings = [], path = "baseline.json", io: StringIO.new)
    described_class.new(graph, findings, Hashira::CI::Baseline.new(path), io:)
  end

  def scoped(analyzers:, targets:)
    described_class.new(graph, [], Hashira::CI::Baseline.new("baseline.json", analyzers:, targets:))
  end

  def sweeping = Hashira::Focus.new(nil, [])

  def focused = Hashira::Focus.new(nil, ["a.rb"])

  def edges = ["alpha -> beta", "alpha -> core", "beta -> alpha"]

  def seed(findings:, edges: self.edges, version: 2, **recorded)
    File.write("baseline.json", JSON.generate(version:, edges:, findings:, **recorded))
  end

  def saved = JSON.parse(File.read("baseline.json"))

  # What a call returned, and what it wrote.
  def noted
    io = StringIO.new
    [yield(io), io.string]
  end

  def told(findings = [], focus = sweeping) = noted { ratchet(findings, io: it).check(focus) }

  def updated(findings) = noted { ratchet(findings, io: it).update }

  it "writes edges and finding signatures on update, and passes when unchanged" do
    expect(updated([finding("cycle", "alpha")])).to(eq([0, "Baseline updated: 3 edges, 1 findings.\n"]))
    expect(saved).to(
      eq(
        "version" => 7, "packaging" => "folder", "findings" => { "cycle:alpha" => nil },
        "analyzers" => [], "targets" => [], "traces" => { "cycle:alpha" => "cycle||a.rb" },
        "edges" => ["alpha -> beta", "alpha -> core", "beta -> alpha"]
      )
    )
    expect(told([finding("cycle", "alpha")])).to(eq([0, "Ratchet OK: 3 edges, 1 findings, unchanged.\n"]))
  end

  it "records the kinds it knew, and lets pass, with a note, findings of a kind a baseline predates" do
    known = Hashira::CI::Baseline.new("baseline.json", kinds: %w[cycle nil_check])
    described_class.new(graph, [finding("cycle", "alpha")], known, io: StringIO.new).update
    expect(saved["kinds"]).to(eq(%w[cycle nil_check]))
    newer = [finding("cycle", "alpha"), finding("indirection", "A#run"), finding("indirection", "B#run")]
    expect(told(newer)).to(match([0, start_with("Not ratcheted: 2 indirection — kinds this baseline predates.")]))
  end

  it "reads a baseline older than the kinds list by the version each kind arrived in, and by the kinds' new names" do
    seed(
      findings: %w[duplicate_method_call:A#b too_many_instance_variables:C sdp_violation:D].to_h { [it, nil] },
      version: 6, packaging: "folder"
    )
    current = [
      finding("repeated_call", "A#b"), finding("state_sprawl", "C"), finding("unstable_dependency", "D"),
      finding("indirection", "A#b")
    ]
    expect(told(current)).to(
      match([0, include("Not ratcheted: 1 indirection", "Ratchet OK: 3 edges, 4 findings, unchanged.")])
    )
    seed(findings: {}, version: 7, packaging: "folder")
    expect(ratchet(current.last(1)).check(sweeping)).to(eq(1))
  end

  it "counts the findings it was handed, noting how many keys they collapse to" do
    twins = [finding("cycle", "alpha"), finding("cycle", "alpha")]
    expect(updated(twins)).to(eq([0, "Baseline updated: 3 edges, 2 findings (1 distinct).\n"]))
  end

  it "fails with evidence when an edge is new" do
    seed(edges: ["alpha -> beta", "alpha -> core"], findings: [])
    output = capture { expect(described_class.new(graph, [], Hashira::CI::Baseline.new("baseline.json")).check(sweeping)).to(eq(1)) }
    expect(output).to(eq(<<~TEXT))
      NEW EDGE beta -> alpha — introduced by:
        · beta/two.rb:4: Alpha::One
        · beta/two.rb:5: App::Alpha::One

      Ratchet FAILED. Either fix what regressed, or — if it is deliberate —
      record the decision: update the baseline, or accept it with a reason.
    TEXT
  end

  it "fails with the whole finding, not just its signature, when one is new" do
    seed(findings: [])
    clone = finding("duplication", "orders.rb:4", digest: "a3f9c1")
    expect(told([clone])).to(
      match([1, include("NEW FINDING:", "duplication: 2 similar fragments (mass 30)", "· a.rb:1", "Ratchet FAILED")])
    )
  end

  it "fails when a baselined finding gets worse, not only when a new one appears" do
    seed(findings: { "complexity:App#run" => 10 }, version: 4)
    expect(told([scored("complexity", "App#run", 54)])).to(
      match([1, include("WORSE FINDING (was 10, now 54):", "complexity: App#run", "Ratchet FAILED")])
    )
  end

  it "stays quiet when a baselined finding gets better or holds still" do
    seed(findings: { "complexity:App#run" => 10 }, version: 4)
    expect([10, 4].map { ratchet([scored("complexity", "App#run", it)]).check(sweeping) }).to(eq([0, 0]))
  end

  it "reads a baseline recorded before magnitudes as identity-only, without crying regression" do
    seed(findings: ["complexity:App#run"])
    expect(ratchet([scored("complexity", "App#run", 54)]).check(sweeping)).to(eq(0))
  end

  it "records the magnitude of every finding that has one" do
    ratchet([scored("complexity", "App#run", 12), finding("duplication", "orders.rb:4", digest: "a3f9c1")]).update
    expect(saved.values_at("findings", "traces")).to(
      eq(
        [
          { "complexity:App#run" => 12, "duplication:a3f9c1" => 30 },
          { "complexity:App#run" => "complexity|a.rb|a.rb" }
        ]
      )
    )
  end

  it "identifies a clone by its digest, so it survives moving down the file" do
    seed(findings: ["duplication:a3f9c1"])
    expect(ratchet([finding("duplication", "orders.rb:91", digest: "a3f9c1")]).check(sweeping)).to(eq(0))
  end

  it "celebrates a resolved finding, and still asks for the baseline to be relocked" do
    seed(findings: ["complexity:App::Knot#tangled"])
    resolved = include("Findings resolved (improvement!): complexity:App::Knot#tangled")
    expect(told).to(match([3, resolved.and(exclude("Ratchet FAILED"))]))
  end

  it "fails but celebrates removed edges" do
    seed(edges: ["alpha -> beta", "alpha -> core", "beta -> alpha", "core -> alpha"], findings: [])
    celebrated = include(
      "Edges removed (improvement!): core -> alpha", "Lock it in: re-run this command with --update-baseline"
    )
    expect(told).to(match([3, celebrated.and(exclude("Ratchet FAILED"))]))
  end

  it "reads a baseline written before findings were ratcheted as edges-only" do
    File.write("baseline.json", JSON.generate(version: 1, edges:))
    expect(told([finding("cycle", "alpha")])).to(eq([0, "Ratchet OK: 3 edges, 1 findings, unchanged.\n"]))
  end

  it "still reports edges against an old baseline, and stays quiet about findings" do
    File.write("baseline.json", JSON.generate(version: 1, edges: ["alpha -> beta", "alpha -> core"]))
    expect(told([finding("cycle", "alpha")])).to(
      match([1, include("NEW EDGE beta -> alpha").and(exclude("NEW FINDING"))])
    )
  end

  it "keeps accepted entries when rewriting the baseline" do
    accepted = [{ kind: "cycle", package: "app", reason: "by design" }]
    File.write("baseline.json", JSON.generate(version: 1, edges: [], accepted:))
    ratchet.update
    expect(saved.values_at("accepted", "edges")).to(
      match([[accepted.first.transform_keys(&:to_s).transform_values(&:to_s)], have_attributes(size: 3)])
    )
  end

  context "with a namespace run" do
    around { |example| within(Fixtures::RAILS_FILES) { example.run } }

    let(:graph) { pipeline(["app"], packaging: :namespace).last }

    it "refuses to ratchet a folder-mode baseline against it" do
      seed(findings: [])
      expect(ratchet.blocker).to(
        eq(
          "baseline baseline.json was recorded with --package-by folder, but this run uses namespace — " \
            "rerun with --package-by folder, or refresh it with --update-baseline"
        )
      )
    end

    it "records the packaging mode and accepts a matching run" do
      ratchet.update
      expect([saved["packaging"], ratchet.check(sweeping)]).to(eq(["namespace", 0]))
    end
  end

  it "refuses a run that analyzes less, or elsewhere, than the baseline recorded" do
    scoped(analyzers: %i[coupling smells], targets: ["lib/app"]).update
    expect(scoped(analyzers: %i[coupling], targets: ["lib/app"]).blocker).to(
      eq(
        "baseline baseline.json was recorded with the analyzers coupling, smells, but this run uses " \
          "coupling — rerun the recorded way, or refresh it with --update-baseline"
      )
    )
    expect(scoped(analyzers: %i[coupling smells], targets: ["app"]).blocker)
      .to(include("recorded with the directories lib/app, but this run uses app"))
    same = [%i[coupling smells], %i[smells coupling]].map { scoped(analyzers: it, targets: ["lib/app"]).blocker }
    expect(same).to(eq([nil, nil]))
  end

  it "stands aside for a baseline recorded before the scope was written down" do
    seed(findings: [])
    expect(scoped(analyzers: %i[coupling], targets: ["anywhere"]).blocker).to(be_nil)
  end

  it "blocks without a baseline and stands aside with one" do
    expect(ratchet([], "missing.json").blocker).to(eq("no baseline at missing.json — run --update-baseline first"))
    seed(findings: [])
    expect(ratchet.blocker).to(be_nil)
  end

  it "reads per-method repeated calls and per-pair associations a baseline recorded as the grouped findings now" do
    recorded = [
      "repeated_call:Shop#tax", "repeated_call:Shop.levy", "bidirectional_association:Post ⇄ User",
      "repeated_call:Gone#x", "nil_check:Shop#tax"
    ]
    seed(findings: recorded.to_h { [it, nil] })
    grouped = %w[repeated_call:Shop bidirectional_association:User nil_check:Shop#tax].map { smell(*it.split(":")) }
    resolved = start_with("Findings resolved (improvement!): repeated_call:Gone#x\n")
    expect(told(grouped)).to(match([3, resolved.and(exclude("NEW", "Shop", "Post"))]))
  end

  it "carries a finding across a rename instead of calling it resolved and new at once" do
    ratchet([smell("nil_check", "Widget#ready")]).update
    expect(told([smell("nil_check", "Gadget#ready")])).to(eq([0, "Ratchet OK: 3 edges, 1 findings, unchanged.\n"]))
  end

  it "matches a rename one for one, so a finding that arrived with it still fails" do
    ratchet([smell("nil_check", "Widget#ready")]).update
    code, output = told([smell("nil_check", "Gadget#ready"), smell("nil_check", "Gadget#idle")])
    expect([code, output.scan("NEW FINDING:").size]).to(eq([1, 1]))
    expect(output).not_to(include("Findings resolved"))
  end

  it "tells a finding fixed in one method and arrived in another from a rename, when neither carries evidence" do
    ratchet([smell("nil_check", "Shop#tax", shape: "tax-body")]).update
    expect(told([smell("nil_check", "Shop#discount", shape: "discount-body")])).to(
      match([1, include("NEW FINDING:", "Findings resolved (improvement!): nil_check:Shop#tax")])
    )
  end

  it "still carries a rename across when the renamed method's code is unchanged" do
    ratchet([smell("nil_check", "Shop#tax", shape: "tax-body")]).update
    expect(told([smell("nil_check", "Shop#levy", shape: "tax-body")])).to(
      eq([0, "Ratchet OK: 3 edges, 1 findings, unchanged.\n"])
    )
  end

  it "still reports a renamed finding that got worse on the way" do
    ratchet([scored("complexity", "App#run", 10)]).update
    expect(told([scored("complexity", "App#total", 54)])).to(
      match([1, include("WORSE FINDING (was 10, now 54):", "complexity: App#total")])
    )
  end

  it "reads a baseline recorded before traces the old way, reporting a rename as both" do
    seed(findings: { "nil_check:Widget#ready" => nil })
    expect(told([smell("nil_check", "Gadget#ready")])).to(
      match([1, include("NEW FINDING:", "Findings resolved (improvement!): nil_check:Widget#ready")])
    )
  end

  it "fails a focused ratchet on what the named files introduced, without calling the rest resolved" do
    ratchet([finding("cycle", "alpha")]).update
    expect(told([smell("nil_check", "Gadget#idle")], focused)).to(
      match([1, include("NEW FINDING:", "nil_check: Gadget#idle").and(exclude("resolved"))])
    )
  end

  it "carries a rename across a focused ratchet, without judging what it was not shown" do
    ratchet([smell("nil_check", "Widget#ready"), finding("cycle", "alpha")]).update
    expect(told([smell("nil_check", "Gadget#ready")], focused)).to(eq([0, "Ratchet OK: 1 findings, unchanged.\n"]))
  end
end
