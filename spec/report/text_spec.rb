# frozen_string_literal: true

RSpec.describe(Hashira::Report::Text) do
  def view(project, graph, findings, complexity: nil, duplication: nil, hotspots: nil, top: nil)
    Hashira::Report::View.new(project:, graph:, complexity:, duplication:, hotspots:, findings:, top:)
  end

  it "caps the findings list at --top and counts what it withheld" do
    with_pipeline do |project, graph, findings|
      output = capture { described_class.new(view(project, graph, findings, top: 2)).print }
      expect(output).to(include("Findings (6):"))
      expect(output).to(include("… and 4 more — raise the cap with --top, or read them all with --json"))
    end
  end

  it "prints the full report verbatim" do
    with_pipeline do |project, graph, findings|
      output = capture { described_class.new(view(project, graph, findings)).print }

      expect(output).to(eq(<<~TEXT))
        Package (folder) metrics for lib/app  (3 packages, 3 files)

        package  TC  Ca  Ce     I  Cyc
        ------------------------------
        core      1   1   0  0.00  -
        beta      1   1   1  0.50  YES
        alpha     1   1   2  0.67  YES

        Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
                I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

        Dependencies (DependsUpon(refs) -> | <- UsedBy):
          alpha        -> beta(1), core(1)                 <- beta
          beta         -> alpha(2)                         <- alpha
          core         -> (none)                           <- alpha

        Findings (6):
          cycle: alpha and beta depend on each other in a cycle — any change may ripple back around. The cheapest cut is alpha -> beta (1 ref).
              · alpha/one.rb:4: Beta::Two
          sdp_violation: beta (I=0.50) depends on the LESS stable alpha (I=0.67) — churn in alpha will force churn in beta. Invert the edge or extract the stable part of alpha that beta needs.
              · beta/two.rb:4: Alpha::One
              · beta/two.rb:5: App::Alpha::One
          utility_function: App::Alpha::One#call touches no instance state (alpha/one.rb:4). Move it onto the object it serves, or make it private.
          utility_function: App::Alpha::One#support touches no instance state (alpha/one.rb:5). Move it onto the object it serves, or make it private.
          utility_function: App::Beta::Two#call touches no instance state (beta/two.rb:4). Move it onto the object it serves, or make it private.
          utility_function: App::Beta::Two#other touches no instance state (beta/two.rb:5). Move it onto the object it serves, or make it private.

          Full evidence + machine format: hashira --json
      TEXT
    end
  end

  it "reports a healthy structure verbatim" do
    files = { "lib/app/solo/solo.rb" => "module App; class Solo; def a = 1; end; end\n" }
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      output = capture { described_class.new(view(pipeline.project, pipeline.graph, screened)).print }
      expect(output).to(eq(<<~TEXT))
        Package (folder) metrics for lib/app  (1 package, 1 file)

        Only one package found — there are no boundaries to analyze. Pass subdirectories to set them (e.g. hashira lib/gem/*/).

        package  TC  Ca  Ce  I  Cyc
        ---------------------------
        solo      1   0   0  —  -

        Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
                I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

        Dependencies (DependsUpon(refs) -> | <- UsedBy):
          + 1 package with no edges either way

        Findings (0):
          none ✓ — structure is healthy
      TEXT
    end
  end

  it "adds the complexity section and its findings when complexity is present" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      view = view(pipeline.project, pipeline.graph, screened, complexity: pipeline.complexity)
      output = capture { described_class.new(view).print }
      expect(output).to(
        include(
          "Package (folder) metrics", "Cognitive complexity — worst methods",
          "Per-class rollup", "complexity: App::Knot::Tangle#tangled"
        )
      )
    end
  end

  it "renders complexity alone when coupling is skipped (no graph)" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      view = view(pipeline.project, nil, screened, complexity: pipeline.complexity)
      output = capture { described_class.new(view).print }
      expect(output).to(include("Cognitive complexity — worst methods"))
      expect(output).not_to(include("package  TC"))
    end
  end

  it "ranks the hotspots between the complexity tables and the findings" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      view = view(pipeline.project, nil, screened, complexity: pipeline.complexity, hotspots: pipeline.hotspots)
      output = capture { described_class.new(view).print }
      expect(output).to(match(%r{Per-class rollup.*Hotspots — cost × churn.*knot/tangle\.rb\s+12.*Findings \(}m))
    end
  end

  it "lists accepted findings with their recorded reason" do
    within(Fixtures::COMPLEX_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      entry = { "kind" => "complexity", "package" => "App::Knot::Tangle#tangled", "reason" => "legacy tangle" }
      screened = Hashira::CI::Accepted.new([entry]).screen(pipeline.findings)
      view = view(pipeline.project, pipeline.graph, screened, complexity: pipeline.complexity)
      output = capture { described_class.new(view).print }
      expect(output).to(include("Accepted (1):", "~ complexity/App::Knot::Tangle#tangled — legacy tangle"))
    end
  end

  it "truncates long evidence lists with an overflow marker" do
    refs = ->(other) { (1..6).map { "#{other}::X#{it}" }.join(", ") }
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [#{refs.call("B")}]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = [#{refs.call("A")}]; end; end; end\n"
    }
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      output = capture { described_class.new(view(pipeline.project, pipeline.graph, screened)).print }
      expect(output).to(include("· … (2 more)"))
    end
  end

  describe(Hashira::Report::FindingList) do
    def complex(name, cognitive)
      detail = Hashira::Complexity::MethodFinding::Effort.new(
        cognitive:, calls: 1, site: "#{name}.rb:1",
        dominant: "if"
      )
      Hashira::Analysis::Finding.new(kind: "complexity", package: "A##{name}", detail:, evidence: [])
    end

    def smell(kind, name, file = name)
      detail = { site: "#{file}.rb:2", owner: :class }
      Hashira::Analysis::Finding.new(kind:, package: "A##{name}", detail:, evidence: [])
    end

    def findings
      [
        complex("mild", 11), complex("worst", 30), complex("bad", 20),
        smell("nil_check", "n1", "shared"), smell("nil_check", "n2", "shared"), smell("nil_check", "n3"),
        smell("utility_function", "u1")
      ]
    end

    def packages(list) = list.map(&:package)

    it "deals the kinds in turn, each worst first where it has a magnitude, else in the order found" do
      expect(packages(Hashira::Report::Spread.new(findings).to_a)).to(
        eq(%w[A#worst A#n1 A#u1 A#bad A#n2 A#mild A#n3])
      )
    end

    it "deals a doubted finding after every confident one of its kind, whatever its magnitude" do
      doubted = complex("doubted", 50).with(confidence: :low)
      dealt = Hashira::Report::Spread.new([doubted, complex("plain", 12), smell("nil_check", "n1")]).to_a
      expect(packages(dealt)).to(eq(%w[A#plain A#n1 A#doubted]))
    end

    it "deals nothing from nothing" do
      expect(Hashira::Report::Spread.new([]).to_a).to(eq([]))
    end

    it "rolls every kind up into one line above a capped list, most numerous first" do
      printed = capture { described_class.new(findings, top: 2).print }.lines(chomp: true)
      expect(printed.first(5)).to(
        eq(
          [
            "  complexity        3 in 3 files",
            "  nil_check         3 in 2 files",
            "  utility_function  1 in 1 file",
            "",
            "  complexity: A#worst — cognitive 30, 1 calls (worst.rb:1). #{Hashira::Report::Phrases::FLATTEN}"
          ]
        )
      )
      expect(printed.last).to(eq(Hashira::Report::Phrases.withheld(5)))
    end

    it "prints no rollup when every finding fits under the cap" do
      printed = capture { described_class.new(findings).print }
      expect(printed).not_to(include(" in 3 files"))
      expect(printed.lines.size).to(eq(7))
    end
  end

  describe(Hashira::Report::Tally) do
    def finding(kind, package, evidence, detail: nil)
      Hashira::Analysis::Finding.new(kind:, package:, detail:, evidence:)
    end

    it "counts the distinct files a kind names, wherever it names them" do
      findings = [
        finding("cycle", "a", ["models/a.rb:3: B", "models/b.rb:9: A"]),
        finding("cycle", "b", ["models/b.rb:4: C", "models/c.rb:1: B"]),
        finding("duplication", "x/y.rb:5", ["x/y.rb:5-9", "x/z.rb:1-5"]),
        finding("roll_call", "pkg", ["lib/one.rb", "lib/two.rb"]),
        finding("complexity", "A#m", ["if +3 (line 4)"], detail: { site: "a/m.rb:2" })
      ]
      expect(described_class.new(findings).to_h).to(
        eq(
          "cycle" => { count: 2, files: 3 }, "complexity" => { count: 1, files: 1 },
          "duplication" => { count: 1, files: 2 }, "roll_call" => { count: 1, files: 2 }
        )
      )
    end
  end

  describe(Hashira::Report::DependencyMap) do
    def files
      {
        "lib/app/hub/h.rb" => "module App; module Hub; class H; def x = [A::X, B::X]; end; end; end\n",
        "lib/app/a/x.rb" => "module App; module A; class X; end; end; end\n",
        "lib/app/b/x.rb" => "module App; module B; class X; end; end; end\n",
        "lib/app/lone/x.rb" => "module App; module Lone; class X; end; end; end\n",
        "lib/app/solo/x.rb" => "module App; module Solo; class X; end; end; end\n"
      }
    end

    def draw(top)
      analyze(files) { |_project, _census, graph| capture { described_class.new(graph, top:).print } }
    end

    it "leads with the most connected packages and counts the unconnected ones in a line" do
      expect(draw(25)).to(eq(<<~TEXT))
        Dependencies (DependsUpon(refs) -> | <- UsedBy):
          hub          -> a(1), b(1)                       <- (none)
          a            -> (none)                           <- hub
          b            -> (none)                           <- hub
          + 2 packages with no edges either way

      TEXT
    end

    it "caps the rows at --top and says how many it withheld" do
      lines = draw(2).lines(chomp: true)
      expect(lines[1..3]).to(
        eq(
          [
            "  hub          -> a(1), b(1)                       <- (none)",
            "  a            -> (none)                           <- hub",
            Hashira::Report::Phrases.withheld(1)
          ]
        )
      )
    end
  end
end
