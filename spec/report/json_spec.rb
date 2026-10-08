# frozen_string_literal: true

RSpec.describe(Hashira::Report::Json) do
  def view(project, graph, findings, complexity: nil, duplication: nil, hotspots: nil, compact: nil, top: nil)
    Hashira::Report::View.new(project:, graph:, complexity:, duplication:, hotspots:, findings:, compact:, top:)
  end

  def full(pipeline, top: nil)
    findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
    view(
      pipeline.project, pipeline.graph, findings,
      complexity: pipeline.complexity, duplication: pipeline.duplication, hotspots: pipeline.hotspots, top:
    )
  end

  def lengths(report)
    { "findings" => report["findings"], "methods" => report["complexity"]["methods"] }
      .merge("classes" => report["complexity"]["classes"], "duplication" => report["duplication"])
      .merge("hotspots" => report["hotspots"]).transform_values(&:size)
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

  it "indents across lines unless asked to be compact" do
    with_pipeline do |project, graph, findings|
      printed = capture { described_class.new(view(project, graph, findings)).print }
      expect(printed).to(eq("#{JSON.pretty_generate(JSON.parse(printed))}\n"))
    end
  end

  it "lists accepted findings with their message and the reason they were accepted" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]), enabled: %i[complexity])
      entry = { "kind" => "complexity", "package" => "App::Knot::Tangle#tangled", "reason" => "legacy tangle" }
      report = emit(view(pipeline.project, nil, Hashira::CI::Accepted.new([entry]).screen(pipeline.findings)))
      expect(report["accepted"].map { it.values_at("kind", "package", "reason") })
        .to(eq([["complexity", "App::Knot::Tangle#tangled", "legacy tangle"]]))
      expect(report["accepted"].first["message"]).to(start_with("App::Knot::Tangle#tangled — cognitive 12"))
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
      expect(report["complexity"]["classes"])
        .to(eq([{ "name" => "App::Knot::Tangle", "cognitive" => 12, "method_count" => 3, "peak" => 12 }]))
    end
  end

  it "includes duplication clusters when supplied" do
    within(Fixtures::DUPLICATION_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      findings = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      report = emit(view(pipeline.project, pipeline.graph, findings, duplication: pipeline.duplication))
      expect(report["duplication"].first).to(include("sites" => 2, "kind" => "literal"))
    end
  end

  it "caps every ranked list at an explicit --top and says how many each withheld" do
    within(Fixtures::DUPLICATION_FILES.merge(Fixtures::COMPLEX_FILES)) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      whole = emit(full(pipeline))
      capped = emit(full(pipeline, top: 1))
      expect(lengths(capped).values).to(all(eq(1)))
      expect(capped["withheld"]).to(eq(lengths(whole).transform_values { it - 1 }))
      expect(capped["findings"]).to(eq(whole["findings"].first(1)))
      expect(capped["packages"]).to(eq(whole["packages"]))
    end
  end

  it "withholds nothing and says nothing about it unless --top is given" do
    with_pipeline do |project, graph, findings|
      report = emit(view(project, graph, findings))
      expect(report).not_to(have_key("withheld"))
      expect(emit(view(project, graph, findings, top: 50))["withheld"]).to(eq("findings" => 0))
    end
  end

  it "tallies every kind with the files it touches, withheld findings included" do
    with_pipeline do |project, graph, findings|
      expect(emit(view(project, graph, findings, top: 1))["kinds"]).to(
        eq(
          "utility_function" => { "count" => 4, "files" => 2 },
          "cycle" => { "count" => 1, "files" => 1 }, "sdp_violation" => { "count" => 1, "files" => 1 }
        )
      )
    end
  end

  it "deals the findings across kinds in the order the text report shows them" do
    with_pipeline do |project, graph, findings|
      expected = Hashira::Report::Spread.new(findings.all).to_a.map(&:package)
      expect(emit(view(project, graph, findings))["findings"].map { it["package"] }).to(eq(expected))
    end
  end

  it "rates each finding's confidence by how directly it follows from the code" do
    with_pipeline do |project, graph, findings|
      rated = emit(view(project, graph, findings))["findings"].to_h { [it["kind"], it["confidence"]] }
      expect(rated).to(eq("cycle" => "high", "sdp_violation" => "high", "utility_function" => "medium"))
    end
  end

  describe(Hashira::Report::Confidence) do
    def clone(variance)
      detail = Hashira::Duplication::DuplicationFinding::Overlap.new(size: 2, mass: 30, kind: variance, hot: false)
      Hashira::Analysis::Finding.new(kind: "duplication", package: "a.rb:1", detail:, evidence: [])
    end

    it "trusts a clone that differs only in one narrow way, doubts one whose control flow differs" do
      kinds = %i[identical literal message constant mixed renamed renamed_literal nil_guard renamed_nil_guard structure
        convention]
      rated = kinds.map { described_class.of(clone(it)) }
      expect(rated).to(eq(%w[high high high high medium medium medium medium medium low low]))
    end

    it "takes the confidence a finding states over the one its kind implies" do
      stated = %i[low high].map { Hashira::Analysis::Finding.new(kind: "nil_check", package: "p", evidence: [], confidence: it) }
      expect(stated.map { described_class.of(it) }).to(eq(%w[low high]))
    end

    it "treats every structural kind and complexity as measured, and every smell as a pattern" do
      rate = ->(kind) { described_class.of(Hashira::Analysis::Finding.new(kind:, package: "p", evidence: [])) }
      expect([*Hashira::Pipeline::STRUCTURAL, "complexity"].map(&rate).uniq).to(eq(["high"]))
      expect(Hashira::Pipeline::SMELLS.map(&rate).uniq).to(eq(["medium"]))
    end
  end
end
