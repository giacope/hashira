# frozen_string_literal: true

RSpec.describe Hashira::CLI::Options do
  describe ".parse" do
    it "defaults to text mode with the default baseline" do
      options = described_class.parse(%w[lib])
      expect(options.directories).to eq(%w[lib])
      expect(options.mode).to eq(:text)
      expect(options.baseline).to eq("hashira_baseline.json")
      expect(options.fail_on).to eq([])
    end

    it "keeps multiple directories in order" do
      expect(described_class.parse(%w[app lib]).directories).to eq(%w[app lib])
    end

    it "parses --update-baseline and --ratchet with a custom --baseline" do
      options = described_class.parse(%w[lib --update-baseline --baseline custom.json])
      expect(options.mode).to eq(:update_baseline)
      expect(options.baseline).to eq("custom.json")
      expect(described_class.parse(%w[lib --ratchet]).mode).to eq(:ratchet)
    end

    it "parses --json and --format" do
      expect(described_class.parse(%w[--json]).mode).to eq(:json)
      expect(described_class.parse(%w[--format json]).mode).to eq(:json)
      expect(described_class.parse(%w[--format dot]).mode).to eq(:dot)
      expect(described_class.parse(%w[--format mermaid]).mode).to eq(:mermaid)
      expect(described_class.parse(%w[--format text]).mode).to eq(:text)
    end

    it "rejects an unknown format" do
      expect { described_class.parse(%w[--format png]) }
        .to raise_error(Hashira::Error, 'unknown --format "png" (use: text, json, dot, mermaid)')
    end

    it "maps --fail-on names to finding kinds, deduplicated" do
      options = described_class.parse(%w[lib --fail-on cycles,sdp,cycle])
      expect(options.mode).to eq(:fail_on)
      expect(options.fail_on).to eq(%w[cycle sdp_violation])
    end

    it "accepts every friendly --fail-on alias" do
      options = described_class.parse(%w[--fail-on cycle,sdp_violation])
      expect(options.fail_on).to eq(%w[cycle sdp_violation])
    end

    it "rejects an unknown --fail-on kind, listing the valid ones" do
      expected = "unknown --fail-on kind \"typos\" (use: #{Hashira::CLI::FailOn::KINDS.keys.join(", ")})"
      expect { described_class.parse(%w[--fail-on typos]) }
        .to raise_error(Hashira::Error, expected)
    end

    it "requires a value after a value flag" do
      expect { described_class.parse(%w[lib --baseline]) }
        .to raise_error(Hashira::Error, "--baseline needs a value")
    end

    it "rejects stray unknown flags, single-dash included" do
      expect { described_class.parse(%w[lib --verbose]) }
        .to raise_error(Hashira::Error, "unknown option --verbose")
      expect { described_class.parse(%w[lib -x]) }
        .to raise_error(Hashira::Error, "unknown option -x")
    end

    it "rejects conflicting mode flags" do
      expect { described_class.parse(%w[--ratchet --format dot]) }
        .to raise_error(Hashira::Error, "conflicting options: --ratchet and --format dot")
      expect { described_class.parse(%w[--json --format dot]) }
        .to raise_error(Hashira::Error, "conflicting options: --format dot and --json")
      expect { described_class.parse(%w[--ratchet --fail-on cycles]) }
        .to raise_error(Hashira::Error, "conflicting options: --ratchet and --fail-on")
    end

    it "tolerates redundant format flags" do
      expect(described_class.parse(%w[--json --format json]).mode).to eq(:json)
    end
  end
end
