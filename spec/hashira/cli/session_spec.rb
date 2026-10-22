# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Session, :aggregate_failures) do
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

  # The exit status and what the run printed.
  def ran(arguments)
    status = nil
    capture { status = described_class.new(arguments).status }.then { [status, it] }
  end

  def status(arguments) = ran(arguments).first

  def parsed(arguments) = ran(arguments).then { |code, output| [code, JSON.parse(output)] }

  def within_history(files)
    within(files) do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      yield
    end
  end

  def twins
    tangle = Fixtures::COMPLEX_FILES.fetch("lib/app/knot/tangle.rb")
    { "one/lib/knot/tangle.rb" => tangle, "two/lib/knot/tangle.rb" => tangle.sub("Tangle", "Snarl") }
  end

  def rails_root
    {
      "app/models/user.rb" => "class User; def a = 1; end\n", "lib/tools/x.rb" => "class X; def a = 1; end\n",
      "config/application.rb" => ""
    }
  end

  it "prints help and version without analysing anything" do
    help = [
      "Usage: hashira", "Options:\n  --format FORMAT      text (default), json, dot, or mermaid\n",
      "  --compact            emit JSON on one line, without the indentation\n                       " \
        "meant for reading\n"
    ]
    expect(ran(["--help"])).to(match([0, include(*help)]))
    expect(ran(["--version"])).to(eq([0, "hashira #{Hashira::VERSION}\n"]))
  end

  context "with a cyclic project" do
    around { |example| within(Fixtures::CYCLIC_FILES) { example.run } }

    it "prints a text report and returns 0" do
      expect(ran(["lib/app"])).to(match([0, include("Package (folder) metrics for lib/app")]))
    end

    it "dispatches --json, --format dot, and --fail-on" do
      code, report = parsed(["lib/app", "--json"])
      expect([code, report["packages"].keys]).to(match([0, contain_exactly("alpha", "beta", "core")]))
      expect(ran(["lib/app", "--format", "dot"])).to(match([0, start_with("digraph hashira {")]))
      expect(ran(["lib/app", "--fail-on", "cycles"])).to(match([1, include("Gate FAILED")]))
    end

    it "gates a plain run on the config file's fail-on, and leaves --json alone" do
      File.write(".hashira.yml", "directories: lib/app\nfail-on: cycles\n")
      expect(ran([])).to(match([1, include("Gate FAILED")]))
      code, report = parsed(["--json"])
      expect([code, report["targets"]]).to(eq([0, %w[lib/app]]))
    end

    it "refuses to ratchet without a baseline" do
      expect { expect(described_class.new(["lib/app", "--ratchet"]).status).to(eq(2)) }
        .to(output(/no baseline at/).to_stderr)
    end

    it "round-trips the ratchet: update then check" do
      expect([%w[--update-baseline], %w[--ratchet]].map { status(["lib/app", *it]) }).to(eq([0, 0]))
      expect(File).to(exist("hashira_baseline.json"))
    end

    it "keeps only the findings that name the files --only lists" do
      expect(ran(["lib/app"])).to(match([0, include("cycle: alpha")]))
      expect(ran(["lib/app", "--only", "lib/app/core/util.rb"])).to(
        match([0, include("Package (folder) metrics", "Findings (0)")])
      )
    end

    it "ratchets a focused run on regressions alone, staying quiet about the rest of the project" do
      expect(status(["lib/app", "--update-baseline"])).to(eq(0))
      File.write("lib/app/beta/two.rb", <<~RUBY)
        module App
          module Beta
            class Two
              def call = 1
            end
          end
        end
      RUBY
      expect(ran(["lib/app", "--ratchet"])).to(match([3, include("Edges removed", "Findings resolved")]))
      expect(ran(["lib/app", "--ratchet", "--only", "lib/app/core/util.rb"])).to(
        eq([0, "Ratchet OK: 0 findings, unchanged.\n"])
      )
    end

    it "keeps only the findings of the kinds --kind names, in text and in JSON" do
      expect(ran(["lib/app", "--kind", "cycles"])).to(
        match(
          [0, include("Package (folder) metrics", "Findings (1):", "cycle: alpha").and(exclude("utility_function"))]
        )
      )
      code, report = parsed(["lib/app", "--json", "--kind", "smells"])
      expect([code, report["findings"].map { it["kind"] }.uniq]).to(eq([0, %w[utility_function]]))
      expect(ran(["lib/app", "--kind", "cycles,smells", "--fail-on", "smells"])).to(match([1, exclude("cycle:")]))
    end

    it "reports the default smells in a plain run, leaves opt-in kinds out, and gates on one that --fail-on names" do
      expect(ran(["lib/app"]).last).to(include("utility_function").and(exclude("repeated_conditional")))
      expect(ran(%w[lib/app --fail-on utility_function])).to(
        match([1, include("Gate FAILED: 4 finding(s) — utility_function 4.")])
      )
    end

    it "gates --fail-on all on every kind the run checks, without turning an opt-in kind on" do
      expect(ran(%w[lib/app --fail-on all])).to(
        match([1, include("Gate FAILED: 5 finding(s) — utility_function 4, cycle 1.")])
      )
      expect(ran(%w[lib/app --fail-on all --kind sdp])).to(
        eq([0, "Gate OK: no findings of kind unstable_dependency.\n"])
      )
      expect(ran(%w[lib/app --fail-on all --skip coupling,smells,duplication])).to(
        eq([0, "Gate OK: no findings of kind complexity, fragmentation.\n"])
      )
    end

    it "ratchets a run narrowed by --kind on those kinds alone, like a focused run" do
      expect(status(["lib/app", "--update-baseline"])).to(eq(0))
      File.write("lib/app/beta/two.rb", "module App; module Beta; class Two; #{utilities}; end; end; end\n")
      expect(status(%w[lib/app --ratchet])).to(eq(1))
      expect(ran(%w[lib/app --ratchet --kind cycles])).to(eq([0, "Ratchet OK: 0 findings, unchanged.\n"]))
      expect(ran(%w[lib/app --ratchet --kind utility_function])).to(
        match([1, include("NEW FINDING:", "utility_function: App::Beta::Two#")])
      )
    end

    def utilities = %w[help name hash].map { "def #{it}_of = Core::Util.#{it}" }.join("; ")

    it "tells a terminal what it reads, what it had to work around, and how long it took" do
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

  it "treats a verified interpreted model as compliant architecture" do
    within(interpretation) do
      code, report = parsed(%w[lib/app --json --skip duplication,complexity,coupling])
      expect([code, report.values_at("findings", "accepted")]).to(eq([0, [[], []]]))
    end
  end

  it "reads an interpreted model declared in .hashira.yml, with no baseline to hold it" do
    declared = <<~YAML
      boundaries:
        - {root: Prism, role: interpreted_model, entrypoint: lib/app/trees.rb, reason: the input}
    YAML
    files = interpretation.except("hashira_baseline.json")
    found = [files.merge(".hashira.yml" => declared), files].map { within(it) { ran(sprawl).last[/Findings \(\d+\)/] } }
    expect(found).to(eq(["Findings (0)", "Findings (1)"]))
  end

  def sprawl = %w[lib/app --kind boundary_sprawl --skip duplication,complexity,coupling]

  context "with a complex project" do
    around { |example| within(Fixtures::COMPLEX_FILES) { example.run } }

    it "skips an analyzer on request" do
      expect(ran(%w[lib/app --skip complexity])).to(
        match([0, include("Package (folder) metrics").and(exclude("Cognitive complexity"))])
      )
      expect(ran(%w[lib/app --skip coupling])).to(
        match([0, include("Cognitive complexity").and(exclude("Package (folder) metrics"))])
      )
      expect(ran(%w[lib/app --skip duplication])).to(match([0, include("Package (folder) metrics")]))
    end

    it "drops the hotspot rollup when both analyzers feeding it are skipped" do
      expect(ran(["lib/app", "--skip", "complexity,duplication"])).to(
        match([0, include("Package (folder) metrics").and(exclude("Hotspots"))])
      )
    end

    it "gates on cognitive complexity findings" do
      expect(ran(["lib/app", "--fail-on", "complexity"])).to(match([1, include("Gate FAILED")]))
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
    within(rails_root) do
      code, report = parsed(["--json"])
      expect([code, report["targets"], report.dig("complexity", "methods").map { it["file"] }]).to(
        match([0, %w[app lib], contain_exactly("app/models/user.rb", "lib/tools/x.rb")])
      )
    end
  end

  it "names files and churn by the same full path when several directories hold same-named files" do
    within_history(twins) do
      code, report = parsed(%w[one/lib two/lib --json])
      expect([code, report["hotspots"].to_h { [it["file"], it["churn"]] }]).to(
        eq([0, { "one/lib/knot/tangle.rb" => 1, "two/lib/knot/tangle.rb" => 1 }])
      )
    end
  end

  it "takes --only by the full path when several directories hold same-named files" do
    within_history(twins) do
      found = parsed(%w[one/lib two/lib --json --only two/lib]).last["findings"]
      expect([found.map { it["package"] }, found.map { it["detail"]["site"] }.compact.uniq]).to(
        match(
          [
            include("App::Knot::Snarl#tangled").and(exclude("App::Knot::Tangle#tangled")),
            eq(["two/lib/knot/tangle.rb:8"])
          ]
        )
      )
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

  it "says nothing about churn when the analyzed repo has history" do
    within_history("lib/app/x.rb" => "class X; def a = 1; end\n") do
      capture do
        expect { expect(described_class.new(["lib/app"]).status).to(eq(0)) }.not_to(output(/no git history/).to_stderr)
      end
    end
  end

  def expect_warning(arguments, said)
    capture { expect { described_class.new(arguments).status }.to(output(/#{Regexp.escape(said)}/).to_stderr) }
  end

  it "says how many files it analysed and which vendored or generated ones it left out" do
    files = {
      "lib/app/good.rb" => "class Good; def a = 1; end\n", "lib/app/vendor/x.rb" => "",
      "lib/app/y.rb" => "# @generated\n"
    }
    said = "hashira: analysed 1 files in lib/app; skipped 1 vendored and 1 generated " \
      "(pass the directory, or --only a file, to analyse them)"
    within(files) { expect_warning(["lib/app"], said) }
  end

  it "says how many files sit in no declared layer, and in which folders" do
    files = {
      ".hashira.yml" => "layers: rails\n", "config/application.rb" => "",
      "app/models/user.rb" => "class User; def a = 1; end\n", "config/initializers/a.rb" => "",
      "app/forms/sign_up.rb" => "class SignUp; def a = User; end\n"
    }
    said = "hashira: 2 of 4 files sit in no layer (config/initializers 1, config 1) — layer_violation"
    within(files) { expect_warning(%w[app config], said) }
  end

  def unparsed
    { "lib/app/good.rb" => "class Good; def a = 1; end\n", "lib/app/broken.rb" => "class Broken\n  def (\nend\n" }
  end

  it "says when a file did not parse, instead of quietly analyzing a partial tree" do
    within(unparsed) do
      capture do
        expect { expect(described_class.new(["lib/app"]).status).to(eq(0)) }
          .to(output(%r{hashira: 1 of the files did not parse — lib/app/broken\.rb}).to_stderr)
      end
    end
  end

  def unreadable_literals
    {
      "r/lib/x/bad.rb" => "module X; BAD = \"\\xFF\".b; end\n",
      "r/lib/x/sender.rb" => <<~'RUBY',
        module X
          class Sender
            LIST = ["\xFFa", "\xFFb"]
            def initialize(io) = @io = io
            def pack(item) = @io.write("\xFF#{item}")
            def call(name) = public_send("\xFF#{name}")
            def check(value) = value == "\xFF" ? LIST : { "\xFF" => 1 }
            define_method("\xFF") { @io }
          end
        end
      RUBY
      "r/lib/x/fields.rb" => "module X\n  class Fields\n    attr_reader :\"\\xFF\", :b\n  end\nend\n",
      "r/.hashira.yml" => "checks: all\n"
    }
  end

  it "analyzes literals whose escapes spell bytes that are not UTF-8, in every format and the ratchet" do
    within(unreadable_literals) do
      expect(ran(["r/lib"])).to(match([0, include("data_class: X::Fields holds '\uFFFD', 'b' and does nothing else")]))
      expect(parsed(["r/lib", "--json"]).last["findings"].map { it["kind"] }).to(include("data_class"))
      expect([%w[--update-baseline], %w[--ratchet]].map { status(["r/lib", *it]) }).to(eq([0, 0]))
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
        expect(
          [JSON.parse(File.read("proj/hashira_baseline.json"))["targets"], File.exist?("here/hashira_baseline.json")]
        ).to(eq([["lib/app"], false]))
        Dir.chdir("proj") { expect(run(%w[lib/app --ratchet])).to(include("Ratchet OK")) }
      end
    end

    it "reads a config's baseline setting from the config's own folder, and its other settings as given" do
      files = {
        "proj/.hashira.yml" => "baseline: ci/base.json\npackage-by: namespace\n", "proj/lib/app/cart.rb" => cart
      }
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
        expect(kinds.keys).to(include("complexity").and(exclude("utility_function")))
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

    def explained = table("# hashira:disable-next-line complexity -- generated table")

    it "lists what they silence and which ones silence nothing, in text" do
      within("lib/app/table.rb" => explained) do
        expect(capture { described_class.new(%w[lib/app --fail-on complexity]).status }).to(include("Gate OK"))
        expect(capture { described_class.new(%w[lib/app]).status }).to(
          include("Suppressed (1):\n  ~ complexity/Table#step — generated table (table.rb:2)")
            .and(include("Unused suppressions (1)", "? complexity at table.rb:12"))
        )
      end
    end

    it "lists what they silence and which ones silence nothing, in JSON" do
      within("lib/app/table.rb" => explained) do
        json = JSON.parse(capture { described_class.new(%w[lib/app --json]).status })
        expect([json["suppressed"].first.slice("kind", "site", "reason"), json["unused_suppressions"].size]).to(
          eq([{ "kind" => "complexity", "site" => "table.rb:2", "reason" => "generated table" }, 1])
        )
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
