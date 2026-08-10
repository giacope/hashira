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
      expected = "unknown --fail-on kind \"typos\" (use: #{Hashira::CLI::FailOn::KINDS.keys.join(", ")})"
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

    it "refuses to skip every analyzer" do
      expect { described_class.parse(%w[--skip coupling,complexity,duplication,smells]) }
        .to(raise_error(Hashira::Error, "cannot skip every analyzer"))
    end
  end
end
