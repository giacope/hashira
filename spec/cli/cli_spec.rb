# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Session) do
  def boundary
    {
      root: "Prism", role: "interpreted_model", entrypoint: "lib/app/trees.rb",
      reason: "the AST is the input model"
    }
  end

  def interpretation
    3.times.to_h { ["lib/app/check#{it}.rb", probes(it)] }.merge(
      "lib/app/trees.rb" => "TREE = Prism.parse('1').value\n",
      "hashira_baseline.json" => JSON.generate(boundaries: [boundary])
    )
  end

  def probes(slot)
    "class Check#{slot}\nprivate\n#{Array.new(4) { probe(it) }.join("\n")}\nend\n"
  end

  def probe(index) = "def probe#{index}(node) = node.is_a?(Prism::CallNode)"

  it "prints a text report and returns 0" do
    within(Fixtures::CYCLIC_FILES) do
      nil
      status = nil
      output = capture { status = described_class.new(["lib/app"]).status }
      expect(status).to(eq(0))
      expect(output).to(include("Package (folder) metrics for lib/app"))
    end
  end

  it "prints help and version without analysing anything" do
    help = capture { expect(described_class.new(["--help"]).status).to(eq(0)) }
    expect(help).to(include("Usage: hashira"))
    expect(help).to(
      include(
        "Options:\n  --format FORMAT      text (default), json, dot, or mermaid\n",
        "  --compact            emit JSON on one line, without the indentation\n                       " \
          "meant for reading\n"
      )
    )
    version = capture { expect(described_class.new(["--version"]).status).to(eq(0)) }
    expect(version).to(eq("hashira #{Hashira::VERSION}\n"))
  end

  it "dispatches --json, --format dot, and --fail-on" do
    within(Fixtures::CYCLIC_FILES) do
      json = capture { expect(described_class.new(["lib/app", "--json"]).status).to(eq(0)) }
      expect(JSON.parse(json)["packages"].keys).to(contain_exactly("alpha", "beta", "core"))
      dot = capture { expect(described_class.new(["lib/app", "--format", "dot"]).status).to(eq(0)) }
      expect(dot).to(start_with("digraph hashira {"))
      gate = capture { expect(described_class.new(["lib/app", "--fail-on", "cycles"]).status).to(eq(1)) }
      expect(gate).to(include("Gate FAILED"))
    end
  end

  it "gates a plain run on the config file's fail-on, and leaves --json alone" do
    within(Fixtures::CYCLIC_FILES.merge(".hashira.yml" => "directories: lib/app\nfail-on: cycles\n")) do
      gate = capture { expect(described_class.new([]).status).to(eq(1)) }
      expect(gate).to(include("Gate FAILED"))
      json = capture { expect(described_class.new(["--json"]).status).to(eq(0)) }
      expect(JSON.parse(json)["targets"]).to(eq(%w[lib/app]))
    end
  end

  it "treats a verified interpreted model as compliant architecture" do
    within(interpretation) do
      arguments = %w[lib/app --json --skip duplication,complexity,coupling]
      report = JSON.parse(capture { expect(described_class.new(arguments).status).to(eq(0)) })
      expect(report.values_at("findings", "accepted")).to(eq([[], []]))
    end
  end

  it "refuses to ratchet without a baseline" do
    within(Fixtures::CYCLIC_FILES) do
      status = nil
      expect { status = described_class.new(["lib/app", "--ratchet"]).status }.to(output(/no baseline at/).to_stderr)
      expect(status).to(eq(2))
    end
  end

  it "skips an analyzer on request" do
    within(Fixtures::COMPLEX_FILES) do
      slim = capture { expect(described_class.new(["lib/app", "--skip", "complexity"]).status).to(eq(0)) }
      expect(slim).to(include("Package (folder) metrics"))
      expect(slim).not_to(include("Cognitive complexity"))
      bare = capture { expect(described_class.new(["lib/app", "--skip", "coupling"]).status).to(eq(0)) }
      expect(bare).to(include("Cognitive complexity"))
      expect(bare).not_to(include("Package (folder) metrics"))
      pruned = capture { expect(described_class.new(["lib/app", "--skip", "duplication"]).status).to(eq(0)) }
      expect(pruned).to(include("Package (folder) metrics"))
    end
  end

  it "drops the hotspot rollup when both analyzers feeding it are skipped" do
    within(Fixtures::COMPLEX_FILES) do
      lone =
        capture do
          expect(described_class.new(["lib/app", "--skip", "complexity,duplication"]).status).to(eq(0))
        end
      expect(lone).to(include("Package (folder) metrics"))
      expect(lone).not_to(include("Hotspots"))
    end
  end

  it "gates on cognitive complexity findings" do
    within(Fixtures::COMPLEX_FILES) do
      gate = capture { expect(described_class.new(["lib/app", "--fail-on", "complexity"]).status).to(eq(1)) }
      expect(gate).to(include("Gate FAILED"))
    end
  end

  it "round-trips the ratchet: update then check" do
    within(Fixtures::CYCLIC_FILES) do
      capture do
        expect(described_class.new(["lib/app", "--update-baseline"]).status).to(eq(0))
        expect(described_class.new(["lib/app", "--ratchet"]).status).to(eq(0))
      end
      expect(File).to(exist("hashira_baseline.json"))
    end
  end

  it "keeps only the findings that name the files --only lists" do
    within(Fixtures::CYCLIC_FILES) do
      whole = capture { expect(described_class.new(["lib/app"]).status).to(eq(0)) }
      expect(whole).to(include("cycle: alpha"))
      part = capture { expect(described_class.new(["lib/app", "--only", "lib/app/core/util.rb"]).status).to(eq(0)) }
      expect(part).to(include("Package (folder) metrics"))
      expect(part).to(include("Findings (0)"))
    end
  end

  it "ratchets a focused run on regressions alone, staying quiet about the rest of the project" do
    within(Fixtures::CYCLIC_FILES) do
      capture { expect(described_class.new(["lib/app", "--update-baseline"]).status).to(eq(0)) }
      File.write("lib/app/beta/two.rb", <<~RUBY)
        module App
          module Beta
            class Two
              def call = 1
            end
          end
        end
      RUBY
      whole = capture { expect(described_class.new(["lib/app", "--ratchet"]).status).to(eq(3)) }
      expect(whole).to(include("Edges removed", "Findings resolved"))
      focused = ["lib/app", "--ratchet", "--only", "lib/app/core/util.rb"]
      part = capture { expect(described_class.new(focused).status).to(eq(0)) }
      expect(part).to(eq("Ratchet OK: 0 findings, unchanged.\n"))
    end
  end

  it "keeps only the findings of the kinds --kind names, in text and in JSON" do
    within(Fixtures::CYCLIC_FILES) do
      text = capture { expect(described_class.new(["lib/app", "--kind", "cycles"]).status).to(eq(0)) }
      expect(text).to(include("Package (folder) metrics", "Findings (1):", "cycle: alpha"))
      expect(text).not_to(include("utility_function"))
      json = capture { expect(described_class.new(["lib/app", "--json", "--kind", "smells"]).status).to(eq(0)) }
      expect(JSON.parse(json)["findings"].map { it["kind"] }.uniq).to(eq(%w[utility_function]))
      gate = ["lib/app", "--kind", "cycles,smells", "--fail-on", "smells"]
      expect(capture { expect(described_class.new(gate).status).to(eq(1)) }).not_to(include("cycle:"))
    end
  end

  it "leaves opt-in kinds out of a plain run and gates on one that --fail-on names" do
    within(Fixtures::CYCLIC_FILES) do
      expect(capture { described_class.new(["lib/app"]).status }).not_to(include("utility_function"))
      gate = capture { expect(described_class.new(%w[lib/app --fail-on utility_function]).status).to(eq(1)) }
      expect(gate).to(include("Gate FAILED: 4 finding(s) — utility_function 4."))
    end
  end

  it "ratchets a run narrowed by --kind on those kinds alone, like a focused run" do
    within(Fixtures::CYCLIC_FILES) do
      capture { expect(described_class.new(["lib/app", "--update-baseline"]).status).to(eq(0)) }
      methods = %w[help name hash].map { "def #{it}_of = Core::Util.#{it}" }.join("; ")
      File.write("lib/app/beta/two.rb", "module App; module Beta; class Two; #{methods}; end; end; end\n")
      capture { expect(described_class.new(["lib/app", "--ratchet"]).status).to(eq(1)) }
      quiet = capture { expect(described_class.new(["lib/app", "--ratchet", "--kind", "cycles"]).status).to(eq(0)) }
      expect(quiet).to(eq("Ratchet OK: 0 findings, unchanged.\n"))
      loud = capture { expect(described_class.new(%w[lib/app --ratchet --kind utility_function]).status).to(eq(1)) }
      expect(loud).to(include("NEW FINDING:", "utility_function: App::Beta::Two#"))
    end
  end

  it "reports unreadable files as a friendly error" do
    within("lib/app/other.rb" => "class Other; def x = 1; end") do
      File.symlink("gone.rb", "lib/app/thing.rb")
      expect do
        expect(described_class.new(["lib/app"]).status).to(eq(2))
      end.to(output(%r{hashira: cannot read lib/app/thing\.rb}).to_stderr)
    end
  end

  it "reads the application and lib/ on a bare run in a Rails root, naming every file from the root" do
    files = {
      "app/models/user.rb" => "class User; def a = 1; end\n", "lib/tools/x.rb" => "class X; def a = 1; end\n",
      "config/application.rb" => ""
    }
    within(files) do
      report = JSON.parse(capture { expect(described_class.new(["--json"]).status).to(eq(0)) })
      expect(report["targets"]).to(eq(%w[app lib]))
      files = report.dig("complexity", "methods").map { it["file"] }
      expect(files).to(contain_exactly("app/models/user.rb", "lib/tools/x.rb"))
    end
  end

  it "names files, churn and --only by the same full path when several directories hold same-named files" do
    tangle = Fixtures::COMPLEX_FILES.fetch("lib/app/knot/tangle.rb")
    within("one/lib/knot/tangle.rb" => tangle, "two/lib/knot/tangle.rb" => tangle.sub("Tangle", "Snarl")) do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      report = JSON.parse(capture { expect(described_class.new(%w[one/lib two/lib --json]).status).to(eq(0)) })
      expect(report["hotspots"].to_h { [it["file"], it["churn"]] })
        .to(eq("one/lib/knot/tangle.rb" => 1, "two/lib/knot/tangle.rb" => 1))
      focused = JSON.parse(capture { described_class.new(%w[one/lib two/lib --json --only two/lib]).status })
      expect(focused["findings"].map { it["package"] }).to(include("App::Knot::Snarl#tangled"))
      expect(focused["findings"].map { it["package"] }).not_to(include("App::Knot::Tangle#tangled"))
      expect(focused["findings"].map { it["detail"]["site"] }.compact.uniq).to(eq(["two/lib/knot/tangle.rb:8"]))
    end
  end

  def on_terminal
    original = [$stdout, $stderr]
    $stdout = StringIO.new
    $stderr = StringIO.new.tap { |io| def io.tty? = true }
    yield
    $stderr.string
  ensure
    $stdout, $stderr = original
  end

  it "tells a terminal what it reads, what it had to work around, and how long it took" do
    within(Fixtures::CYCLIC_FILES) do
      told = on_terminal { expect(described_class.new(["lib/app"]).status).to(eq(0)) }
      expect(told.lines).to(
        match(
          [
            "hashira: reading 3 files in lib/app…\n",
            "hashira: no git history for lib/app — hotspots are ranked by cost alone\n",
            /\Ahashira: 3 files in \d+\.\ds\n\z/
          ]
        )
      )
    end
  end

  it "says nothing about churn when the analyzed repo has history" do
    within("lib/app/x.rb" => "class X; def a = 1; end\n") do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      capture do
        expect { expect(described_class.new(["lib/app"]).status).to(eq(0)) }.not_to(output(/no git history/).to_stderr)
      end
    end
  end

  it "says when a file did not parse, instead of quietly analyzing a partial tree" do
    files = {
      "lib/app/good.rb" => "class Good; def a = 1; end\n",
      "lib/app/broken.rb" => "class Broken\n  def (\nend\n"
    }
    within(files) do
      capture do
        expect { expect(described_class.new(["lib/app"]).status).to(eq(0)) }
          .to(output(%r{hashira: 1 of the files did not parse — lib/app/broken\.rb}).to_stderr)
      end
    end
  end

  it "refuses a baseline it cannot read, and an unwritable one" do
    within("lib/app/x.rb" => "class X; def a = 1; end\n", "b.json" => "{ oops") do
      expect { expect(described_class.new(["lib/app", "--baseline", "b.json"]).status).to(eq(2)) }
        .to(output(/b\.json is not a usable baseline/).to_stderr)
      unwritable = %w[lib/app --update-baseline --baseline nope/b.json]
      expect { expect(described_class.new(unwritable).status).to(eq(2)) }
        .to(output(%r{\Ahashira: cannot write nope/b\.json \(No such file or directory @ rb_sysopen}).to_stderr)
    end
  end

  it "prints user-facing errors to stderr and exits 2 for misuse" do
    expect do
      expect(described_class.new(["missing_directory"]).status).to(eq(2))
    end.to(output("hashira: no such directory: missing_directory\n").to_stderr)
  end

  it "turns an unexpected failure into an exit 70 and a line worth reporting" do
    expect do
      expect(described_class.new([nil]).status).to(eq(70))
    end.to(output(%r{\Ahashira: internal error — \w+.*\n  at .*\n.*report it at https://}m).to_stderr)
  end

  describe "run from outside the analyzed project" do
    def cart = "class Cart\n  def initialize(i) = @i = i\n  def total = @i.sum\n  def price(it) = it.amount\nend\n"

    def json(argv) = JSON.parse(capture { expect(described_class.new(argv).status).to(eq(0)) })

    def run(argv) = capture { described_class.new(argv).status }

    it "reads the project's own baseline and config, never the ones where it runs" do
      accepted = { kind: "utility_function", package: "Cart#price", reason: "kept public" }
      files = {
        "tool/hashira_baseline.json" => JSON.generate(boundaries: [boundary]), "tool/.hashira.yml" => "fail-on: x\n",
        "proj/hashira_baseline.json" => JSON.generate(accepted: [accepted]), "proj/lib/app/cart.rb" => cart,
        "proj/.hashira.yml" => "checks: all\n"
      }
      within(files) { Dir.chdir("tool") { expect(json(%w[../proj/lib/app --json])["accepted"].size).to(eq(1)) } }
    end

    it "records the project's baseline in the project, with its directories named from there" do
      within("proj/Gemfile" => "", "proj/lib/app/cart.rb" => cart, "here/README" => "") do
        Dir.chdir("here") { run(%w[../proj/lib/app --update-baseline]) }
        expect(JSON.parse(File.read("proj/hashira_baseline.json"))["targets"]).to(eq(["lib/app"]))
        expect(File.exist?("here/hashira_baseline.json")).to(be(false))
        Dir.chdir("proj") { expect(run(%w[lib/app --ratchet])).to(include("Ratchet OK")) }
      end
    end

    it "reads a config's baseline setting from the config's own folder, and its other settings as given" do
      yaml = "baseline: ci/base.json\npackage-by: namespace\n"
      files = { "proj/.hashira.yml" => yaml, "proj/lib/app/cart.rb" => cart }
      within(files.merge("proj/ci/README" => "", "here/README" => "")) do
        Dir.chdir("here") { run(%w[../proj/lib/app --update-baseline]) }
        expect(JSON.parse(File.read("proj/ci/base.json"))["packaging"]).to(eq("namespace"))
      end
    end
  end

  describe "checks in the config file" do
    def gate = "class Gate\n  def open?(a, b)\n    if a\n      b ? 1 : 2\n    end\n  end\nend\n"

    def cart = "class Cart\n  def price(i) = i.round\nend\n"

    it "moves a threshold and turns a kind off" do
      yaml = "checks:\n  complexity:\n    threshold: 3\n  utility_function: false\n"
      within(".hashira.yml" => yaml, "lib/app/gate.rb" => gate, "lib/app/cart.rb" => cart) do
        kinds = JSON.parse(capture { described_class.new(%w[lib/app --json]).status })["kinds"]
        expect(kinds.keys).to(include("complexity"))
        expect(kinds.keys).not_to(include("utility_function"))
      end
    end

    it "names the file when a check is wrong" do
      within(".hashira.yml" => "checks:\n  envy: false\n", "lib/app/gate.rb" => gate) do
        expect { described_class.new(%w[lib/app]).status }
          .to(output(/\.hashira\.yml: checks: unknown kind "envy"/).to_stderr)
      end
    end
  end

  describe "inline suppressions" do
    def table(comment)
      "class Table\n  #{comment}\n  def step(a, b, c, d)\n    if a\n      if b\n        if c\n          " \
        "d ? 1 : 2\n        end\n      end\n    end\n  end\n  " \
        "def calm = 1 # hashira:disable complexity -- stale\nend\n"
    end

    it "lists what they silence and which ones silence nothing, in text and JSON" do
      within("lib/app/table.rb" => table("# hashira:disable-next-line complexity -- generated table")) do
        gated = capture { described_class.new(%w[lib/app --fail-on complexity]).status }
        expect(gated).to(include("Gate OK"))
        expect(capture { described_class.new(%w[lib/app]).status }).to(
          include("Suppressed (1):\n  ~ complexity/Table#step — generated table (table.rb:2)")
            .and(include("Unused suppressions (1)", "? complexity at table.rb:12"))
        )
        json = JSON.parse(capture { described_class.new(%w[lib/app --json]).status })
        expect(json["suppressed"].first.slice("kind", "site", "reason")).to(
          eq("kind" => "complexity", "site" => "table.rb:2", "reason" => "generated table")
        )
        expect(json["unused_suppressions"].size).to(eq(1))
      end
    end

    it "refuses a suppression without a reason as misuse, even when only the graph is drawn" do
      within("lib/app/table.rb" => table("# hashira:disable-next-line complexity")) do
        expect { expect(described_class.new(%w[lib/app]).status).to(eq(2)) }.to(output(/needs a reason/).to_stderr)
        expect { expect(described_class.new(%w[lib/app --format dot]).status).to(eq(2)) }
          .to(output(/needs a reason/).to_stderr)
      end
    end
  end
end
