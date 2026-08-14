# frozen_string_literal: true

RSpec.describe(Hashira::CI::Ratchet) do
  def with_graph(&)
    analyze(Fixtures::CYCLIC_FILES) { |_project, _census, graph| yield(graph) }
  end

  def finding(kind, package, digest: nil)
    Hashira::Analysis::Finding.new(
      kind:, package:, digest:, evidence: ["a.rb:1"],
      detail: Hashira::Duplication::DuplicationFinding::Overlap.new(size: 2, mass: 30, kind: :identical, hot: false)
    )
  end

  def ratchet(graph, findings = [], path = "baseline.json", io: StringIO.new)
    described_class.new(graph, findings, Hashira::CI::Baseline.new(path), io:)
  end

  def edges = ["alpha -> beta", "alpha -> core", "beta -> alpha"]

  def seed(findings:, edges: self.edges)
    File.write("baseline.json", JSON.generate(version: 2, edges:, findings:))
  end

  it "writes edges and finding signatures on update, and passes when unchanged" do
    with_graph do |graph|
      io = StringIO.new
      expect(ratchet(graph, [finding("cycle", "alpha")], io:).update).to(eq(0))
      expect(io.string).to(eq("Baseline updated: 3 edges, 1 findings.\n"))

      saved = JSON.parse(File.read("baseline.json"))
      expect(saved).to(
        eq(
          "version" => 4, "packaging" => "folder", "findings" => { "cycle:alpha" => nil },
          "analyzers" => [], "targets" => [],
          "edges" => ["alpha -> beta", "alpha -> core", "beta -> alpha"]
        )
      )

      io.truncate(io.pos = 0)
      expect(ratchet(graph, [finding("cycle", "alpha")], io:).check).to(eq(0))
      expect(io.string).to(eq("Ratchet OK: 3 edges, 1 findings, unchanged.\n"))
    end
  end

  it "counts the findings it was handed, noting how many keys they collapse to" do
    with_graph do |graph|
      io = StringIO.new
      twins = [finding("cycle", "alpha"), finding("cycle", "alpha")]
      expect(ratchet(graph, twins, io:).update).to(eq(0))
      expect(io.string).to(eq("Baseline updated: 3 edges, 2 findings (1 distinct).\n"))
    end
  end

  it "fails with evidence when an edge is new" do
    with_graph do |graph|
      seed(edges: ["alpha -> beta", "alpha -> core"], findings: [])
      output = capture { expect(described_class.new(graph, [], Hashira::CI::Baseline.new("baseline.json")).check).to(eq(1)) }
      expect(output).to(eq(<<~TEXT))
        NEW EDGE beta -> alpha — introduced by:
          · beta/two.rb:4: Alpha::One
          · beta/two.rb:5: App::Alpha::One

        Ratchet FAILED. Either fix what regressed, or — if it is deliberate —
        record the decision: update the baseline, or accept it with a reason.
      TEXT
    end
  end

  it "fails with the whole finding, not just its signature, when one is new" do
    with_graph do |graph|
      seed(findings: [])
      clone = finding("duplication", "orders.rb:4", digest: "a3f9c1")

      output = capture { expect(ratchet(graph, [clone], "baseline.json", io: $stdout).check).to(eq(1)) }

      expect(output).to(
        include(
          "NEW FINDING:", "duplication: 2 similar fragments (mass 30)", "· a.rb:1",
          "Ratchet FAILED"
        )
      )
    end
  end

  def scored(kind, package, value)
    Hashira::Analysis::Finding.new(
      kind:, package:, evidence: ["a.rb:1"],
      detail: Hashira::Complexity::MethodFinding::Effort.new(cognitive: value, calls: 3, site: "a.rb:1", dominant: "if")
    )
  end

  it "fails when a baselined finding gets worse, not only when a new one appears" do
    with_graph do |graph|
      File.write("baseline.json", JSON.generate(version: 4, edges:, findings: { "complexity:App#run" => 10 }))
      io = StringIO.new
      expect(ratchet(graph, [scored("complexity", "App#run", 54)], "baseline.json", io:).check).to(eq(1))
      expect(io.string).to(include("WORSE FINDING (was 10, now 54):", "complexity: App#run"))
      expect(io.string).to(include("Ratchet FAILED"))
    end
  end

  it "stays quiet when a baselined finding gets better or holds still" do
    with_graph do |graph|
      File.write("baseline.json", JSON.generate(version: 4, edges:, findings: { "complexity:App#run" => 10 }))
      expect(ratchet(graph, [scored("complexity", "App#run", 10)], "baseline.json").check).to(eq(0))
      expect(ratchet(graph, [scored("complexity", "App#run", 4)], "baseline.json").check).to(eq(0))
    end
  end

  it "reads a baseline recorded before magnitudes as identity-only, without crying regression" do
    with_graph do |graph|
      seed(findings: ["complexity:App#run"])
      expect(ratchet(graph, [scored("complexity", "App#run", 54)], "baseline.json").check).to(eq(0))
    end
  end

  it "records the magnitude of every finding that has one" do
    with_graph do |graph|
      findings = [scored("complexity", "App#run", 12), finding("cycle", "alpha")]
      ratchet(graph, findings).update
      saved = JSON.parse(File.read("baseline.json"))
      expect(saved["findings"]).to(eq("complexity:App#run" => 12, "cycle:alpha" => nil))
    end
  end

  it "identifies a clone by its digest, so it survives moving down the file" do
    with_graph do |graph|
      seed(findings: ["duplication:a3f9c1"])
      moved = finding("duplication", "orders.rb:91", digest: "a3f9c1")

      expect(ratchet(graph, [moved]).check).to(eq(0))
    end
  end

  it "celebrates a resolved finding, and still asks for the baseline to be relocked" do
    with_graph do |graph|
      seed(findings: ["complexity:App::Knot#tangled"])

      output = capture { expect(ratchet(graph, [], "baseline.json", io: $stdout).check).to(eq(3)) }

      expect(output).to(include("Findings resolved (improvement!): complexity:App::Knot#tangled"))
      expect(output).not_to(include("Ratchet FAILED"))
    end
  end

  it "fails but celebrates removed edges" do
    with_graph do |graph|
      seed(edges: ["alpha -> beta", "alpha -> core", "beta -> alpha", "core -> alpha"], findings: [])
      output = capture { expect(described_class.new(graph, [], Hashira::CI::Baseline.new("baseline.json")).check).to(eq(3)) }
      expect(output).to(include("Edges removed (improvement!): core -> alpha"))
      expect(output).to(include("Lock it in: re-run this command with --update-baseline"))
      expect(output).not_to(include("Ratchet FAILED"))
    end
  end

  it "reads a baseline written before findings were ratcheted as edges-only" do
    with_graph do |graph|
      edges = ["alpha -> beta", "alpha -> core", "beta -> alpha"]
      File.write("baseline.json", JSON.generate(version: 1, edges:))
      io = StringIO.new

      expect(ratchet(graph, [finding("cycle", "alpha")], io:).check).to(eq(0))
      expect(io.string).to(eq("Ratchet OK: 3 edges, 1 findings, unchanged.\n"))
    end
  end

  it "still reports edges against an old baseline, and stays quiet about findings" do
    with_graph do |graph|
      File.write("baseline.json", JSON.generate(version: 1, edges: ["alpha -> beta", "alpha -> core"]))
      current = [finding("cycle", "alpha")]

      output = capture { expect(ratchet(graph, current, "baseline.json", io: $stdout).check).to(eq(1)) }

      expect(output).to(include("NEW EDGE beta -> alpha"))
      expect(output).not_to(include("NEW FINDING"))
    end
  end

  it "keeps accepted entries when rewriting the baseline" do
    with_graph do |graph|
      accepted = [{ kind: "cycle", package: "app", reason: "by design" }]
      File.write("baseline.json", JSON.generate(version: 1, edges: [], accepted:))
      ratchet(graph).update
      saved = JSON.parse(File.read("baseline.json"))
      expect(saved["accepted"]).to(eq([accepted.first.transform_keys(&:to_s).transform_values(&:to_s)]))
      expect(saved["edges"].size).to(eq(3))
    end
  end

  it "refuses to ratchet a folder-mode baseline against a namespace run" do
    analyze(Fixtures::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      seed(findings: [])
      expect(ratchet(graph).blocker).to(match(/recorded with --package-by folder.*rerun with --package-by folder/))
    end
  end

  it "records the packaging mode and accepts a matching run" do
    analyze(Fixtures::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      io = StringIO.new
      ratchet(graph, [], io:).update
      expect(JSON.parse(File.read("baseline.json"))["packaging"]).to(eq("namespace"))
      expect(ratchet(graph, [], io:).check).to(eq(0))
    end
  end

  def scoped(graph, analyzers:, targets:)
    described_class.new(graph, [], Hashira::CI::Baseline.new("baseline.json", analyzers:, targets:))
  end

  it "refuses a run that analyzes less, or elsewhere, than the baseline recorded" do
    with_graph do |graph|
      scoped(graph, analyzers: %i[coupling smells], targets: ["lib/app"]).update
      expect(scoped(graph, analyzers: %i[coupling], targets: ["lib/app"]).blocker)
        .to(include("recorded with the analyzers coupling, smells, but this run uses coupling"))
      expect(scoped(graph, analyzers: %i[coupling smells], targets: ["app"]).blocker)
        .to(include("recorded with the directories lib/app, but this run uses app"))
      expect(scoped(graph, analyzers: %i[coupling smells], targets: ["lib/app"]).blocker).to(be_nil)
    end
  end

  it "stands aside for a baseline recorded before the scope was written down" do
    with_graph do |graph|
      seed(findings: [])
      expect(scoped(graph, analyzers: %i[coupling], targets: ["anywhere"]).blocker).to(be_nil)
    end
  end

  it "blocks without a baseline and stands aside with one" do
    with_graph do |graph|
      expect(described_class.new(graph, [], Hashira::CI::Baseline.new("missing.json")).blocker)
        .to(eq("no baseline at missing.json — run --update-baseline first"))
      seed(findings: [])
      expect(ratchet(graph).blocker).to(be_nil)
    end
  end
end
