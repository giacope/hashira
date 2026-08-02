# frozen_string_literal: true

RSpec.describe(Hashira::CI::Ratchet) do
  def with_graph(&)
    analyze(FixtureHelper::CYCLIC_FILES) { |_project, _census, graph| yield(graph) }
  end

  def finding(kind, package, digest: nil)
    Hashira::Analysis::Finding.new(kind:, package:, digest:, message: "#{package} is #{kind}", evidence: ["a.rb:1"])
  end

  def ratchet(graph, findings = [], path = "baseline.json", io: StringIO.new)
    described_class.new(graph, findings, path, io:)
  end

  def seed(findings:, edges: ["alpha -> beta", "alpha -> core", "beta -> alpha"])
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
          "version" => 3, "packaging" => "folder", "findings" => ["cycle:alpha"],
          "edges" => ["alpha -> beta", "alpha -> core", "beta -> alpha"]
        )
      )

      io.truncate(io.pos = 0)
      expect(ratchet(graph, [finding("cycle", "alpha")], io:).check).to(eq(0))
      expect(io.string).to(eq("Ratchet OK: 3 edges, 1 findings, unchanged.\n"))
    end
  end

  it "fails with evidence when an edge is new" do
    with_graph do |graph|
      seed(edges: ["alpha -> beta", "alpha -> core"], findings: [])
      output = capture { expect(described_class.new(graph, [], "baseline.json").check).to(eq(1)) }
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
          "NEW FINDING:", "duplication: orders.rb:4 is duplication", "· a.rb:1",
          "Ratchet FAILED"
        )
      )
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

      output = capture { expect(ratchet(graph, [], "baseline.json", io: $stdout).check).to(eq(1)) }

      expect(output).to(include("Findings resolved (improvement!): complexity:App::Knot#tangled"))
      expect(output).not_to(include("Ratchet FAILED"))
    end
  end

  it "fails but celebrates removed edges" do
    with_graph do |graph|
      seed(edges: ["alpha -> beta", "alpha -> core", "beta -> alpha", "core -> alpha"], findings: [])
      output = capture { expect(described_class.new(graph, [], "baseline.json").check).to(eq(1)) }
      expect(output).to(include("Edges removed (improvement!): core -> alpha"))
      expect(output).to(include("Lock it in: hashira --update-baseline"))
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
    analyze(FixtureHelper::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      seed(findings: [])
      expect { ratchet(graph).check }.to(
        raise_error(Hashira::Error, /recorded with --package-by folder.*rerun with --package-by folder/)
      )
    end
  end

  it "records the packaging mode and accepts a matching run" do
    analyze(FixtureHelper::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      io = StringIO.new
      ratchet(graph, [], io:).update
      expect(JSON.parse(File.read("baseline.json"))["packaging"]).to(eq("namespace"))
      expect(ratchet(graph, [], io:).check).to(eq(0))
    end
  end

  it "raises without a baseline" do
    with_graph do |graph|
      expect { described_class.new(graph, [], "missing.json").check }
        .to(raise_error(Hashira::Error, "no baseline at missing.json — run --update-baseline first"))
    end
  end
end
