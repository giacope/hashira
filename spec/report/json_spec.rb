# frozen_string_literal: true

RSpec.describe Hashira::Report::Json do
  def view_for(project, graph, findings, complexity: nil, duplication: nil, hotspots: nil)
    Hashira::Report::View.new(project:, graph:, complexity:, duplication:, hotspots:, findings:)
  end

  def emit(view) = JSON.parse(capture_stdout { described_class.new(view).print })

  it "emits packages sorted by instability, edges with evidence, and findings" do
    with_pipeline do |project, graph, findings|
      report = emit(view_for(project, graph, findings))

      expect(report["packages"].keys).to eq(%w[core beta alpha])
      expect(report["packages"]["alpha"])
        .to eq("tc" => 1, "ca" => 1, "ce" => 2, "i" => 2.0 / 3, "cyclic" => true)
      expect(report["packages"]["core"]["cyclic"]).to be(false)
      expect(report["edges"]).to include(
        "from" => "alpha", "to" => "core", "weight" => 1, "refs" => ["alpha/one.rb:5: Core::Util"]
      )
      expect(report["findings"].map { it["kind"] }).to eq(%w[cycle cycle sdp_violation])
    end
  end

  it "omits analyzer keys that were skipped" do
    with_pipeline do |project, graph, findings|
      report = emit(view_for(project, graph, findings))
      expect(report).not_to have_key("complexity")
      expect(report).not_to have_key("duplication")
    end
  end

  it "omits coupling keys when no graph is present" do
    within_project(FixtureHelper::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      report = emit(view_for(pipeline.project, nil, findings, complexity: pipeline.complexity))
      expect(report).not_to have_key("packages")
      expect(report["complexity"]["methods"].first).to include("subject" => "App::Knot::Tangle#tangled")
    end
  end

  it "includes duplication clusters when supplied" do
    within_project(FixtureHelper::DUPLICATION_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      report = emit(view_for(pipeline.project, pipeline.graph, findings, duplication: pipeline.duplication))
      expect(report["duplication"].first).to include("sites" => 2, "kind" => "mixed")
    end
  end
end
