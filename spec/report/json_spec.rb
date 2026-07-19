# frozen_string_literal: true

RSpec.describe Hashira::Report::Json do
  it "emits packages sorted by instability, edges with evidence, and findings" do
    with_pipeline do |_project, graph, findings|
      report = JSON.parse(capture_stdout { described_class.new(graph, findings).print })

      expect(report["packages"].keys).to eq(%w[core beta alpha])
      expect(report["packages"]["alpha"])
        .to eq("tc" => 1, "ca" => 1, "ce" => 2, "i" => 2.0 / 3, "cyclic" => true)
      expect(report["packages"]["core"]["cyclic"]).to be(false)

      expect(report["edges"]).to include(
        "from" => "alpha", "to" => "core", "weight" => 1, "refs" => ["alpha/one.rb:5: Core::Util"]
      )
      expect(report["edges"].map { [_1["from"], _1["to"]] })
        .to eq([%w[alpha beta], %w[alpha core], %w[beta alpha]])

      expect(report["findings"].map { _1["kind"] }).to eq(%w[cycle cycle sdp_violation])
    end
  end
end
