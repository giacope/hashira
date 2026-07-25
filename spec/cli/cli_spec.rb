# frozen_string_literal: true

RSpec.describe Hashira::CLI do
  it "prints a text report and returns 0" do
    within_project(FixtureHelper::CYCLIC_FILES) do
      nil
      status = nil
      output = capture_stdout { status = described_class.run(["lib/app"]) }
      expect(status).to eq(0)
      expect(output).to include("Package (layer) metrics for lib/app")
    end
  end

  it "prints help and version without analysing anything" do
    help = capture_stdout { expect(described_class.run(["--help"])).to eq(0) }
    expect(help).to include("Usage: hashira")

    version = capture_stdout { expect(described_class.run(["--version"])).to eq(0) }
    expect(version).to eq("hashira #{Hashira::VERSION}\n")
  end

  it "dispatches --json, --format dot, and --fail-on" do
    within_project(FixtureHelper::CYCLIC_FILES) do
      json = capture_stdout { expect(described_class.run(["lib/app", "--json"])).to eq(0) }
      expect(JSON.parse(json)["packages"].keys).to contain_exactly("alpha", "beta", "core")

      dot = capture_stdout { expect(described_class.run(["lib/app", "--format", "dot"])).to eq(0) }
      expect(dot).to start_with("digraph hashira {")

      gate = capture_stdout { expect(described_class.run(["lib/app", "--fail-on", "cycles"])).to eq(1) }
      expect(gate).to include("Gate FAILED")
    end
  end

  it "skips an analyzer on request" do
    within_project(FixtureHelper::COMPLEX_FILES) do
      without_complexity = capture_stdout { expect(described_class.run(["lib/app", "--skip", "complexity"])).to eq(0) }
      expect(without_complexity).to include("Package (layer) metrics")
      expect(without_complexity).not_to include("Cognitive complexity")

      without_coupling = capture_stdout { expect(described_class.run(["lib/app", "--skip", "coupling"])).to eq(0) }
      expect(without_coupling).to include("Cognitive complexity")
      expect(without_coupling).not_to include("Package (layer) metrics")

      skip_dupe = capture_stdout { expect(described_class.run(["lib/app", "--skip", "duplication"])).to eq(0) }
      expect(skip_dupe).to include("Package (layer) metrics")
    end
  end

  it "drops the hotspot rollup when both analyzers feeding it are skipped" do
    within_project(FixtureHelper::COMPLEX_FILES) do
      coupling_only = capture_stdout do
        expect(described_class.run(["lib/app", "--skip", "complexity,duplication"])).to eq(0)
      end

      expect(coupling_only).to include("Package (layer) metrics")
      expect(coupling_only).not_to include("Hotspots")
    end
  end

  it "gates on cognitive complexity findings" do
    within_project(FixtureHelper::COMPLEX_FILES) do
      gate = capture_stdout { expect(described_class.run(["lib/app", "--fail-on", "complexity"])).to eq(1) }
      expect(gate).to include("Gate FAILED")
    end
  end

  it "round-trips the ratchet: update then check" do
    within_project(FixtureHelper::CYCLIC_FILES) do
      capture_stdout do
        expect(described_class.run(["lib/app", "--update-baseline"])).to eq(0)
        expect(described_class.run(["lib/app", "--ratchet"])).to eq(0)
      end
      expect(File).to exist("hashira_baseline.json")
    end
  end

  it "reports unreadable files as a friendly error" do
    within_project("lib/app/thing.rb" => "class Thing; def x = 1; end") do
      File.chmod(0o000, "lib/app/thing.rb")
      expect do
        expect(described_class.run(["lib/app"])).to eq(1)
      end.to output(%r{hashira: cannot read lib/app/thing\.rb}).to_stderr
    ensure
      File.chmod(0o644, "lib/app/thing.rb")
    end
  end

  it "prints user-facing errors to stderr and returns 1" do
    expect do
      expect(described_class.run(["missing_directory"])).to eq(1)
    end.to output("hashira: no such directory: missing_directory\n").to_stderr
  end
end
