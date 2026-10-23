# frozen_string_literal: true

RSpec.describe(Hashira::Report::Json, :aggregate_failures) do
  def view(project, graph, findings, complexity: nil, duplication: nil, hotspots: nil, compact: nil, top: nil)
    Hashira::Report::View.new(
      project:, graph:, complexity:, duplication:, hotspots:, findings:, compact:, top:, screened: Fixtures::CLEAR
    )
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

  def cyclic_report = with_pipeline { |project, graph, findings| emit(view(project, graph, findings)) }

  # The JSON report of a pipeline run over the files: with its graph or without, and with the parts named.
  def reported(files, graph: true, parts: [], directories: ["lib/app"], accepted: [], **)
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(directories), **)
      findings = Hashira::CI::Accepted.new(accepted).screen(pipeline.findings)
      emit(view(pipeline.project, (pipeline.graph if graph), findings, **parts.to_h { [it, pipeline.public_send(it)] }))
    end
  end

  def capped_at(files, top)
    within(files) { emit(full(Hashira::Pipeline.new(Hashira::Project.new(["lib/app"])), top:)) }
  end

  def legacy = { "kind" => "complexity", "package" => "App::Knot::Tangle#tangled", "reason" => "legacy tangle" }
  it "lists no unjudged kinds when every kind the run asked for was judged" do
    expect(cyclic_report).not_to(have_key("unjudged"))
  end

  it "says what produced it: schema version, packaging, targets, and file count" do
    expect(cyclic_report.values_at("version", "packaging", "targets", "files"))
      .to(eq([Hashira::Report::Json::SCHEMA, "folder", ["lib/app"], 3]))
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
    report = reported(Fixtures::COMPLEX_FILES, graph: false, accepted: [legacy], enabled: %i[complexity])
    expect(report["accepted"].map { it.values_at("kind", "package", "reason", "message") }).to(
      match(
        [
          [
            "complexity", "App::Knot::Tangle#tangled", "legacy tangle",
            start_with("App::Knot::Tangle#tangled — cognitive 12")
          ]
        ]
      )
    )
  end

  it "emits packages sorted by instability, edges with evidence, and findings" do
    packages, edges, findings = cyclic_report.values_at("packages", "edges", "findings")
    expect([packages.keys, packages["alpha"], packages["core"]["cyclic"]]).to(
      eq([%w[core beta alpha], { "tc" => 1, "ca" => 1, "ce" => 2, "i" => 2.0 / 3, "cyclic" => true }, false])
    )
    expect(edges).to(include("from" => "alpha", "to" => "core", "weight" => 1, "refs" => ["alpha/one.rb:5: Core::Util"]))
    expect(findings.map { it["kind"] }).to(eq(%w[cycle] + (["utility_function"] * 4)))
  end

  it "lists folds when packaging folded packages, and an empty list otherwise" do
    expect(cyclic_report["folds"]).to(eq([]))
    files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES)
    report = reported(files, directories: ["app"], enabled: %i[coupling])
    expect(report["folds"]).to(include("from" => "SandboxPolicy", "to" => "Sandbox", "via" => "suffix"))
  end

  it "omits analyzer keys that were skipped" do
    with_pipeline do |project, graph, findings|
      report = emit(view(project, graph, findings))
      expect(report).not_to(have_key("complexity"))
      expect(report).not_to(have_key("duplication"))
    end
  end

  it "omits coupling keys when no graph is present" do
    report = reported(Fixtures::COMPLEX_FILES, graph: false, parts: %i[complexity])
    expect(report).not_to(have_key("packages"))
    expect(report["complexity"]["methods"].first).to(include("subject" => "App::Knot::Tangle#tangled"))
    expect(report["complexity"]["classes"])
      .to(eq([{ "name" => "App::Knot::Tangle", "cognitive" => 12, "method_count" => 3, "peak" => 12 }]))
  end

  it "includes duplication clusters when supplied" do
    report = reported(Fixtures::DUPLICATION_FILES, parts: %i[duplication])
    expect(report["duplication"].first).to(include("sites" => 2, "kind" => "literal"))
  end

  it "caps every ranked list at an explicit --top and says how many each withheld" do
    files = Fixtures::DUPLICATION_FILES.merge(Fixtures::COMPLEX_FILES)
    whole, capped = [nil, 1].map { capped_at(files, it) }
    expect(lengths(capped).values).to(all(eq(1)))
    expect(capped["withheld"]).to(eq(lengths(whole).transform_values { it - 1 }))
    expect(capped.values_at("findings", "packages")).to(eq([whole["findings"].first(1), whole["packages"]]))
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
          "cycle" => { "count" => 1, "files" => 1 }
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
      expect(rated).to(eq("cycle" => "high", "utility_function" => "medium"))
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
      rated = kinds.map { described_class.new(clone(it)).of }
      expect(rated).to(eq(%w[high high high high medium medium medium medium medium low low]))
    end

    it "takes the confidence a finding states over the one its kind implies" do
      stated = %i[low high].map { Hashira::Analysis::Finding.new(kind: "nil_check", package: "p", evidence: [], confidence: it) }
      expect(stated.map { described_class.new(it).of }).to(eq(%w[low high]))
    end

    it "treats every structural kind and complexity as measured, and every smell and history guess as a pattern" do
      rate = ->(kind) { described_class.new(Hashira::Analysis::Finding.new(kind:, package: "p", evidence: [])).of }
      guesses = %w[change_coupling dead_code]
      expect([*(Hashira::Pipeline::STRUCTURAL - guesses), "complexity"].map(&rate).uniq).to(eq(["high"]))
      expect([*Hashira::Pipeline::SMELLS, *guesses].map(&rate).uniq).to(eq(["medium"]))
    end
  end
end
