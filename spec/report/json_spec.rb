# frozen_string_literal: true

RSpec.describe(Hashira::Report::Json) do
  def view(project, graph, findings, complexity: nil, duplication: nil, hotspots: nil, compact: nil)
    Hashira::Report::View.new(
      project:, files: project.files.size, graph:, complexity:, duplication:, hotspots:, findings:, compact:
    )
  end

  def emit(view) = JSON.parse(capture { described_class.new(view).print })
  it "says what produced it: schema version, packaging, targets, and file count" do
    with_pipeline do |project, graph, findings|
      report = emit(view(project, graph, findings))
      expect(report["version"]).to(eq(Hashira::Report::Json::SCHEMA))
      expect(report["packaging"]).to(eq("folder"))
      expect(report["targets"]).to(eq(["lib/app"]))
      expect(report["files"]).to(eq(3))
    end
  end

  it "emits one line under --compact, and the same data either way" do
    with_pipeline do |project, graph, findings|
      dense = capture { described_class.new(view(project, graph, findings, compact: true)).print }
      expect(dense.lines.size).to(eq(1))
      expect(JSON.parse(dense)).to(eq(emit(view(project, graph, findings))))
    end
  end

  it "emits packages sorted by instability, edges with evidence, and findings" do
    with_pipeline do |project, graph, findings|
      report = emit(view(project, graph, findings))
      expect(report["packages"].keys).to(eq(%w[core beta alpha]))
      expect(report["packages"]["alpha"]).to(eq("tc" => 1, "ca" => 1, "ce" => 2, "i" => 2.0 / 3, "cyclic" => true))
      expect(report["packages"]["core"]["cyclic"]).to(be(false))
      expect(report["edges"]).to(
        include(
          "from" => "alpha", "to" => "core", "weight" => 1, "refs" => ["alpha/one.rb:5: Core::Util"]
        )
      )
      kinds = %w[cycle sdp_violation] + (["utility_function"] * 4)
      expect(report["findings"].map { it["kind"] }).to(eq(kinds))
    end
  end

  it "lists folds when packaging folded packages, and an empty list otherwise" do
    with_pipeline do |project, graph, findings|
      expect(emit(view(project, graph, findings))["folds"]).to(eq([]))
    end
    files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES)
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]), enabled: %i[coupling])
      report = emit(view(pipeline.project, pipeline.graph, Hashira::CI::Accepted.new([]).screen(pipeline.findings)))
      expect(report["folds"]).to(include("from" => "SandboxResource", "to" => "Sandbox", "via" => "suffix"))
    end
  end

  it "omits analyzer keys that were skipped" do
    with_pipeline do |project, graph, findings|
      report = emit(view(project, graph, findings))
      expect(report).not_to(have_key("complexity"))
      expect(report).not_to(have_key("duplication"))
    end
  end

  it "omits coupling keys when no graph is present" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      report = emit(view(pipeline.project, nil, findings, complexity: pipeline.complexity))
      expect(report).not_to(have_key("packages"))
      expect(report["complexity"]["methods"].first).to(include("subject" => "App::Knot::Tangle#tangled"))
    end
  end

  it "includes duplication clusters when supplied" do
    within(Fixtures::DUPLICATION_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      report = emit(view(pipeline.project, pipeline.graph, findings, duplication: pipeline.duplication))
      expect(report["duplication"].first).to(include("sites" => 2, "kind" => "mixed"))
    end
  end
end
