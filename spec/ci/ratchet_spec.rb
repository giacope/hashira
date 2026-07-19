# frozen_string_literal: true

RSpec.describe Hashira::CI::Ratchet do
  def with_graph(&)
    analyze(FixtureHelper::CYCLIC_FILES) { |_project, _census, graph| yield(graph) }
  end

  it "writes the edge list on update and passes when unchanged" do
    with_graph do |graph|
      io = StringIO.new
      ratchet = described_class.new(graph, "baseline.json", io:)
      expect(ratchet.update).to eq(0)
      expect(io.string).to eq("Baseline updated: 3 edges.\n")

      saved = JSON.parse(File.read("baseline.json"))
      expect(saved).to eq("version" => 1, "edges" => ["alpha -> beta", "alpha -> core", "beta -> alpha"])

      io.truncate(io.pos = 0)
      expect(ratchet.check).to eq(0)
      expect(io.string).to eq("Ratchet OK: 3 edges, unchanged.\n")
    end
  end

  it "fails with evidence when an edge is new" do
    with_graph do |graph|
      File.write("baseline.json", JSON.generate(version: 1, edges: ["alpha -> beta", "alpha -> core"]))
      output = capture_stdout { expect(described_class.new(graph, "baseline.json").check).to eq(1) }
      expect(output).to eq(<<~TEXT)
        NEW EDGE beta -> alpha — introduced by:
          · beta/two.rb:4: Alpha::One
          · beta/two.rb:5: App::Alpha::One

        Ratchet FAILED. Either decouple, or if the new edge is a deliberate
        design decision, update the baseline and say why in the commit.
      TEXT
    end
  end

  it "fails but celebrates removed edges" do
    with_graph do |graph|
      edges = ["alpha -> beta", "alpha -> core", "beta -> alpha", "core -> alpha"]
      File.write("baseline.json", JSON.generate(version: 1, edges:))
      output = capture_stdout { expect(described_class.new(graph, "baseline.json").check).to eq(1) }
      expect(output).to include("Edges removed (improvement!): core -> alpha")
      expect(output).to include("Lock it in: hashira --update-baseline")
      expect(output).not_to include("Ratchet FAILED")
    end
  end

  it "keeps accepted findings when rewriting the baseline" do
    with_graph do |graph|
      accepted = [{ kind: "cycle", package: "app", reason: "by design" }]
      File.write("baseline.json", JSON.generate(version: 1, edges: [], accepted:))
      described_class.new(graph, "baseline.json", io: StringIO.new).update
      saved = JSON.parse(File.read("baseline.json"))
      expect(saved["accepted"]).to eq([accepted.first.transform_keys(&:to_s).transform_values(&:to_s)])
      expect(saved["edges"].size).to eq(3)
    end
  end

  it "raises without a baseline" do
    with_graph do |graph|
      expect { described_class.new(graph, "missing.json").check }
        .to raise_error(Hashira::Error, "no baseline at missing.json — run --update-baseline first")
    end
  end
end
