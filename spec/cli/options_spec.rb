# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Options) do
  describe ".parse" do
    it "defaults to text mode with the default baseline" do
      options = described_class.parse(%w[lib])
      expect(options.directories).to(eq(%w[lib]))
      expect(options.mode).to(eq(:text))
      expect(options.baseline).to(eq("hashira_baseline.json"))
      expect(options.fail_on).to(eq([]))
    end

    it "keeps multiple directories in order" do
      expect(described_class.parse(%w[app lib]).directories).to(eq(%w[app lib]))
    end

    it "parses --update-baseline and --ratchet with a custom --baseline" do
      options = described_class.parse(%w[lib --update-baseline --baseline custom.json])
      expect(options.mode).to(eq(:update))
      expect(options.baseline).to(eq("custom.json"))
      expect(described_class.parse(%w[lib --ratchet]).mode).to(eq(:ratchet))
    end

    it "parses --json and --format" do
      expect(described_class.parse(%w[--json]).mode).to(eq(:json))
      expect(described_class.parse(%w[--format json]).mode).to(eq(:json))
      expect(described_class.parse(%w[--format dot]).mode).to(eq(:dot))
      expect(described_class.parse(%w[--format mermaid]).mode).to(eq(:mermaid))
      expect(described_class.parse(%w[--format text]).mode).to(eq(:text))
    end

    it "rejects an unknown format" do
      expect { described_class.parse(%w[--format png]) }
        .to(raise_error(Hashira::Error, 'unknown --format "png" (use: text, json, dot, mermaid)'))
    end

    it "maps --fail-on names to finding kinds, deduplicated" do
      options = described_class.parse(%w[lib --fail-on cycles,sdp,cycle])
      expect(options.mode).to(eq(:fail_on))
      expect(options.fail_on).to(eq(%w[cycle sdp_violation]))
    end

    it "accepts every friendly --fail-on alias" do
      options = described_class.parse(%w[--fail-on cycle,sdp_violation])
      expect(options.fail_on).to(eq(%w[cycle sdp_violation]))
    end

    it "rejects an unknown --fail-on kind, listing the valid ones" do
      expected = "unknown --fail-on \"typos\" (use: #{Hashira::CLI::FailOn::KINDS.keys.join(", ")})"
      expect { described_class.parse(%w[--fail-on typos]) }.to(raise_error(Hashira::Error, expected))
    end

    it "parses --package-by, defaulting to auto-detection" do
      expect(described_class.parse(%w[lib]).packaging).to(eq(:auto))
      expect(described_class.parse(%w[lib --package-by auto]).packaging).to(eq(:auto))
      expect(described_class.parse(%w[lib --package-by namespace]).packaging).to(eq(:namespace))
      expect(described_class.parse(%w[lib --package-by folder]).packaging).to(eq(:folder))
    end

    it "rejects an unknown --package-by grouping" do
      expect { described_class.parse(%w[lib --package-by team]) }
        .to(raise_error(Hashira::Error, 'unknown --package-by "team" (use: auto, folder, namespace)'))
    end

    it "requires a value after a value flag" do
      expect { described_class.parse(%w[lib --baseline]) }.to(raise_error(Hashira::Error, "--baseline needs a value"))
      expect { described_class.parse(["lib", "--fail-on", ""]) }
        .to(raise_error(Hashira::Error, "--fail-on needs a value"))
    end

    it "refuses a --fail-on list that names no kind" do
      expect { described_class.parse(["lib", "--fail-on", ","]) }
        .to(raise_error(Hashira::Error, "--fail-on needs at least one kind"))
    end

    it "refuses to gate on a kind whose analyzer is skipped" do
      expect { described_class.parse(%w[lib --fail-on cycles --skip coupling]) }
        .to(raise_error(Hashira::Error, "--fail-on cycle needs the coupling analyzer, but --skip drops it"))
      expect { described_class.parse(%w[lib --fail-on feature_envy --skip smells]) }
        .to(raise_error(Hashira::Error, "--fail-on feature_envy needs the smells analyzer, but --skip drops it"))
      expect(described_class.parse(%w[lib --fail-on cycles --skip complexity]).fail_on).to(eq(%w[cycle]))
    end

    it "names a repeated value flag instead of calling it unknown" do
      expect { described_class.parse(%w[lib --format json --format dot]) }
        .to(raise_error(Hashira::Error, "--format given more than once"))
    end

    it "refuses to draw a diagram whose analyzer is skipped" do
      expect { described_class.parse(%w[lib --format dot --skip coupling]) }
        .to(raise_error(Hashira::Error, "--format dot draws the coupling graph, but --skip coupling drops it"))
      expect(described_class.parse(%w[lib --format dot --skip smells]).mode).to(eq(:dot))
    end

    it "refuses --compact for output that is not JSON" do
      expect(described_class.parse(%w[lib --json --compact]).compact).to(be_truthy)
      expect { described_class.parse(%w[lib --compact]) }
        .to(raise_error(Hashira::Error, "--compact shapes JSON, but this run emits text"))
      expect { described_class.parse(%w[lib --format dot --compact]) }
        .to(raise_error(Hashira::Error, "--compact shapes JSON, but this run emits dot"))
    end

    it "rejects stray unknown flags, single-dash included" do
      expect { described_class.parse(%w[lib --verbose]) }.to(raise_error(Hashira::Error, "unknown option --verbose"))
      expect { described_class.parse(%w[lib -x]) }.to(raise_error(Hashira::Error, "unknown option -x"))
    end

    it "rejects conflicting mode flags" do
      expect { described_class.parse(%w[--ratchet --format dot]) }
        .to(raise_error(Hashira::Error, "conflicting options: --format dot and --ratchet"))
      expect { described_class.parse(%w[--json --format dot]) }
        .to(raise_error(Hashira::Error, "conflicting options: --format dot and --json"))
      expect { described_class.parse(%w[--ratchet --fail-on cycles]) }
        .to(raise_error(Hashira::Error, "conflicting options: --fail-on and --ratchet"))
    end

    it "tolerates redundant format flags" do
      expect(described_class.parse(%w[--json --format json]).mode).to(eq(:json))
    end

    it "treats a missing list as nothing to gate or skip" do
      expect(Hashira::CLI::FailOn.parse(nil)).to(eq([]))
      expect(Hashira::CLI::Skip.parse(nil)).to(eq([]))
    end

    it "expands --fail-on smells into every smell kind" do
      parsed = described_class.parse(%w[lib --fail-on cycles,smells])
      expect(parsed.fail_on).to(include("cycle", "feature_envy", "nil_check", "utility_function"))
      expect(described_class.parse(%w[lib --fail-on feature_envy]).fail_on).to(eq(%w[feature_envy]))
    end

    it "defaults --skip to nothing and parses a comma-separated list" do
      expect(described_class.parse(%w[lib]).skip).to(eq([]))
      expect(described_class.parse(%w[lib --skip complexity]).skip).to(eq([:complexity]))
    end

    it "leaves --top unset so each table keeps its own default" do
      expect(described_class.parse(%w[lib]).top).to(be_nil)
      expect(described_class.parse(%w[lib --top 40]).top).to(eq(40))
    end

    it "rejects a --top that is not a positive whole number" do
      %w[0 -1 abc 3.5].each do |value|
        expect { described_class.parse(["lib", "--top", value]) }
          .to(raise_error(Hashira::Error, "--top #{value.inspect} is not a positive whole number"))
      end
    end

    it "rejects an unknown --skip analyzer" do
      expect { described_class.parse(%w[--skip typo]) }
        .to(raise_error(Hashira::Error, 'unknown --skip "typo" (use: coupling, complexity, duplication, smells)'))
    end

    it "defaults --only to nothing and reads a comma-separated list of files" do
      within("lib/app/x.rb" => "class X; def a = 1; end\n") do
        expect(described_class.parse(%w[lib/app]).only).to(eq([]))
        expect(described_class.parse(%w[lib/app --only lib/app/x.rb]).only).to(eq(%w[lib/app/x.rb]))
        expect(described_class.parse(["lib/app", "--only", "./lib/app/x.rb, lib/app/x.rb"]).only)
          .to(eq(%w[lib/app/x.rb lib/app/x.rb]))
        expect(described_class.parse(["lib/app", "--only", "#{Dir.pwd}/lib/app/x.rb"]).only).to(eq(%w[lib/app/x.rb]))
      end
    end

    it "rejects an --only path that is not a file here" do
      expect { described_class.parse(%w[lib --only lib/gone.rb]) }
        .to(raise_error(Hashira::Error, '--only "lib/gone.rb" is not a file or directory here'))
    end

    it "expands an --only directory to every Ruby file under it" do
      within("lib/app/b/y.rb" => "", "lib/app/a/x.rb" => "", "lib/app/a/notes.md" => "", "top.rb" => "") do
        expect(described_class.parse(%w[lib --only lib/app/,lib/app/b/y.rb]).only)
          .to(eq(%w[lib/app/a/x.rb lib/app/b/y.rb lib/app/b/y.rb]))
        expect(described_class.parse(%w[lib --only .]).only).to(eq(%w[lib/app/a/x.rb lib/app/b/y.rb top.rb]))
      end
    end

    it "rejects an --only directory holding no Ruby files, rather than silently reporting everything" do
      within("lib/app/x.rb" => "", "docs/readme.md" => "") do
        expect { described_class.parse(%w[lib --only docs]) }
          .to(raise_error(Hashira::Error, '--only "docs" holds no Ruby files'))
      end
    end

    it "refuses --only for runs that report more than findings" do
      within("lib/app/x.rb" => "class X; def a = 1; end\n") do
        expect { described_class.parse(%w[lib/app --only lib/app/x.rb --update-baseline]) }
          .to(raise_error(Hashira::Error, "--only narrows the findings, but --update-baseline records them all"))
        expect { described_class.parse(%w[lib/app --only lib/app/x.rb --format mermaid]) }
          .to(raise_error(Hashira::Error, "--format mermaid draws the coupling graph, which --only cannot narrow"))
        expect(described_class.parse(%w[lib/app --only lib/app/x.rb --ratchet]).mode).to(eq(:ratchet))
      end
    end

    it "reads --kind with the --fail-on vocabulary, defaulting to every kind" do
      expect(described_class.parse(%w[lib]).kinds).to(eq([]))
      expect(described_class.parse(%w[lib --kind cycles,dupe]).kinds).to(eq(%w[cycle duplication]))
      expect(described_class.parse(%w[lib --kind smells]).kinds).to(eq(Hashira::Pipeline::SMELLS))
      expect(described_class.parse(%w[lib --kind cycles --ratchet]).mode).to(eq(:ratchet))
      expect(described_class.parse(%w[lib --kind cycles,sdp --fail-on sdp]).fail_on).to(eq(%w[sdp_violation]))
    end

    it "rejects an unknown --kind, listing the valid ones" do
      expected = "unknown --kind \"typos\" (use: #{Hashira::CLI::FailOn::KINDS.keys.join(", ")})"
      expect { described_class.parse(%w[--kind typos]) }.to(raise_error(Hashira::Error, expected))
      expect { described_class.parse(["lib", "--kind", ","]) }
        .to(raise_error(Hashira::Error, "--kind needs at least one kind"))
    end

    it "refuses --kind where narrowing the findings would mislead" do
      expect { described_class.parse(%w[lib --kind cycles --update-baseline]) }
        .to(raise_error(Hashira::Error, "--kind narrows the findings, but --update-baseline records them all"))
      expect { described_class.parse(%w[lib --kind cycles --format dot]) }
        .to(raise_error(Hashira::Error, "--format dot draws the coupling graph, which --kind cannot narrow"))
      expect { described_class.parse(%w[lib --kind cycles --skip coupling]) }
        .to(raise_error(Hashira::Error, "--kind cycle needs the coupling analyzer, but --skip drops it"))
      expect { described_class.parse(%w[lib --kind smells --fail-on cycles]) }
        .to(raise_error(Hashira::Error, "--fail-on cycle can never fire, since --kind leaves it out"))
    end

    it "refuses to skip every analyzer" do
      expect { described_class.parse(%w[--skip coupling,complexity,duplication,smells]) }
        .to(raise_error(Hashira::Error, "cannot skip every analyzer"))
    end
  end

  describe "with a config file" do
    def configured(yaml, &) = within(".hashira.yml" => yaml, &)

    def read(*argv, fields) = described_class.parse(argv).to_h.slice(*fields)

    it "reads every setting from .hashira.yml as if its flag were typed" do
      yaml = <<~YAML
        directories: [app, lib]
        fail-on: [cycles, sdp]
        skip: duplication
        kind: cycles,sdp,complexity
        top: 3
        package-by: namespace
        baseline: ci/baseline.json
      YAML
      configured(yaml) do
        expect(read(%i[directories mode fail_on skip kinds top packaging baseline])).to(
          eq(
            directories: %w[app lib], mode: :fail_on, fail_on: %w[cycle sdp_violation], skip: [:duplication],
            kinds: %w[cycle sdp_violation complexity], top: 3, packaging: :namespace, baseline: "ci/baseline.json"
          )
        )
      end
    end

    it "lets a flag on the command line replace its setting" do
      configured("directories: app\nskip: smells\ntop: 3\n") do
        expect(read("lib", "--skip", "complexity", "--top", "7", %i[directories skip top]))
          .to(eq(directories: %w[lib], skip: [:complexity], top: 7))
        expect(read(%i[directories])).to(eq(directories: %w[app]))
      end
    end

    it "steps a setting aside when the command line rules it out, keeping the rest" do
      configured("fail-on: cycles\nkind: cycles,sdp\nskip: smells\n") do
        expect(read("--json", %i[mode fail_on kinds])).to(eq(mode: :json, fail_on: [], kinds: %w[cycle sdp_violation]))
        expect(read("--ratchet", %i[mode fail_on])).to(eq(mode: :ratchet, fail_on: []))
        expect(read("--update-baseline", %i[mode kinds skip])).to(eq(mode: :update, kinds: [], skip: [:smells]))
        expect(read("--skip", "coupling", %i[mode fail_on kinds])).to(eq(mode: :text, fail_on: [], kinds: []))
        expect(read("--fail-on", "feature_envy", %i[fail_on skip kinds]))
          .to(eq(fail_on: %w[feature_envy], skip: [], kinds: []))
      end
      configured("skip: coupling\n") { expect(read("--format", "dot", %i[mode skip])).to(eq(mode: :dot, skip: [])) }
    end

    it "reads another file with --config, and none with --no-config" do
      within(".hashira.yml" => "top: 3\n", "ci/hashira.yml" => "top: 9\n", "empty.yml" => "") do
        expect(read("--config", "ci/hashira.yml", %i[top])).to(eq(top: 9))
        expect(read("--no-config", %i[top])).to(eq(top: nil))
        expect(read("--config", "empty.yml", %i[top])).to(eq(top: nil))
      end
    end

    it "refuses a --config it cannot read" do
      within("ci/hashira.yml" => "top: 9\n") do
        {
          %w[--config ci/hashira.yml --no-config] => "conflicting options: --config and --no-config",
          %w[--config ci] => '--config "ci" is not a file here',
          %w[--config gone.yml] => '--config "gone.yml" is not a file here',
          %w[--config] => "--config needs a value",
          %w[--config ci/hashira.yml --config ci/hashira.yml] => "--config given more than once"
        }.each { |argv, message| expect { described_class.parse(argv) }.to(raise_error(Hashira::Error, message)) }
      end
    end

    it "names the file in every complaint about it" do
      {
        "skipp: x\n" => 'unknown setting "skipp" (use: directories, fail-on, skip, kind, top, package-by, baseline)',
        "- top\n" => 'expected key: value settings, not ["top"]',
        "top: {n: 3}\n" => 'top takes a value or a list of values, not {"n" => 3}',
        "directories: [app, [lib]]\n" => 'directories takes a value or a list of values, not ["app", ["lib"]]',
        "skip: true\n" => "skip takes a value or a list of values, not true",
        "skip:\n" => "--skip needs a value",
        "top: 0\n" => '--top "0" is not a positive whole number',
        "skip: coupling\nfail-on: cycles\n" => "--fail-on cycle needs the coupling analyzer, but --skip drops it"
      }.each do |yaml, message|
        configured(yaml) { expect { described_class.parse([]) }.to(raise_error(Hashira::Error, ".hashira.yml: #{message}")) }
      end
    end

    it "refuses a file that is not plain YAML" do
      {
        "skip: [\n" => "did not find expected node content while parsing a flow node at line 2 column 1",
        "skip: :coupling\n" => "Tried to load unspecified class: Symbol"
      }.each do |yaml, problem|
        configured(yaml) do
          expect { described_class.parse([]) }
            .to(raise_error(Hashira::Error, ".hashira.yml is not plain YAML (#{problem})"))
        end
      end
    end

    it "prints help even when the file is broken" do
      configured("skipp: x\n") { expect(described_class.parse(%w[--help]).mode).to(eq(:help)) }
    end
  end
end
