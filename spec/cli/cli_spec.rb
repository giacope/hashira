# frozen_string_literal: true

RSpec.describe(Hashira::CLI) do
  it "prints a text report and returns 0" do
    within(FixtureHelper::CYCLIC_FILES) do
      nil
      status = nil
      output = capture { status = described_class.run(["lib/app"]) }
      expect(status).to(eq(0))
      expect(output).to(include("Package (folder) metrics for lib/app"))
    end
  end

  it "prints help and version without analysing anything" do
    help = capture { expect(described_class.run(["--help"])).to(eq(0)) }
    expect(help).to(include("Usage: hashira"))
    version = capture { expect(described_class.run(["--version"])).to(eq(0)) }
    expect(version).to(eq("hashira #{Hashira::VERSION}\n"))
  end

  it "dispatches --json, --format dot, and --fail-on" do
    within(FixtureHelper::CYCLIC_FILES) do
      json = capture { expect(described_class.run(["lib/app", "--json"])).to(eq(0)) }
      expect(JSON.parse(json)["packages"].keys).to(contain_exactly("alpha", "beta", "core"))
      dot = capture { expect(described_class.run(["lib/app", "--format", "dot"])).to(eq(0)) }
      expect(dot).to(start_with("digraph hashira {"))
      gate = capture { expect(described_class.run(["lib/app", "--fail-on", "cycles"])).to(eq(1)) }
      expect(gate).to(include("Gate FAILED"))
    end
  end

  it "refuses to ratchet without a baseline" do
    within(FixtureHelper::CYCLIC_FILES) do
      status = nil
      expect { status = described_class.run(["lib/app", "--ratchet"]) }.to(output(/no baseline at/).to_stderr)
      expect(status).to(eq(2))
    end
  end

  it "skips an analyzer on request" do
    within(FixtureHelper::COMPLEX_FILES) do
      slim = capture { expect(described_class.run(["lib/app", "--skip", "complexity"])).to(eq(0)) }
      expect(slim).to(include("Package (folder) metrics"))
      expect(slim).not_to(include("Cognitive complexity"))
      bare = capture { expect(described_class.run(["lib/app", "--skip", "coupling"])).to(eq(0)) }
      expect(bare).to(include("Cognitive complexity"))
      expect(bare).not_to(include("Package (folder) metrics"))
      pruned = capture { expect(described_class.run(["lib/app", "--skip", "duplication"])).to(eq(0)) }
      expect(pruned).to(include("Package (folder) metrics"))
    end
  end

  it "drops the hotspot rollup when both analyzers feeding it are skipped" do
    within(FixtureHelper::COMPLEX_FILES) do
      lone =
        capture do
          expect(described_class.run(["lib/app", "--skip", "complexity,duplication"])).to(eq(0))
        end
      expect(lone).to(include("Package (folder) metrics"))
      expect(lone).not_to(include("Hotspots"))
    end
  end

  it "gates on cognitive complexity findings" do
    within(FixtureHelper::COMPLEX_FILES) do
      gate = capture { expect(described_class.run(["lib/app", "--fail-on", "complexity"])).to(eq(1)) }
      expect(gate).to(include("Gate FAILED"))
    end
  end

  it "round-trips the ratchet: update then check" do
    within(FixtureHelper::CYCLIC_FILES) do
      capture do
        expect(described_class.run(["lib/app", "--update-baseline"])).to(eq(0))
        expect(described_class.run(["lib/app", "--ratchet"])).to(eq(0))
      end
      expect(File).to(exist("hashira_baseline.json"))
    end
  end

  it "reports unreadable files as a friendly error" do
    within("lib/app/thing.rb" => "class Thing; def x = 1; end") do
      File.chmod(0o000, "lib/app/thing.rb")
      expect do
        expect(described_class.run(["lib/app"])).to(eq(2))
      end.to(output(%r{hashira: cannot read lib/app/thing\.rb}).to_stderr)
    ensure
      File.chmod(0o644, "lib/app/thing.rb")
    end
  end

  it "points a bare run in a Rails root at app, without changing what it analyzes" do
    files = { "lib/mygem/x.rb" => "class X; def a = 1; end\n", "config/application.rb" => "" }
    within(files) do
      capture do
        expect { expect(described_class.run([])).to(eq(0)) }.to(output(/looks like a Rails root/).to_stderr)
        expect { expect(described_class.run(["lib"])).to(eq(0)) }.not_to(output(/Rails root/).to_stderr)
      end
    end
  end

  it "says nothing about churn when the analyzed repo has history" do
    within("lib/app/x.rb" => "class X; def a = 1; end\n") do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      capture do
        expect { expect(described_class.run(["lib/app"])).to(eq(0)) }.not_to(output(/no git history/).to_stderr)
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
        expect { expect(described_class.run(["lib/app"])).to(eq(0)) }
          .to(output(%r{hashira: 1 of the files did not parse — lib/app/broken\.rb}).to_stderr)
      end
    end
  end

  it "refuses a baseline it cannot read, and an unwritable one" do
    within("lib/app/x.rb" => "class X; def a = 1; end\n", "b.json" => "{ oops") do
      expect { expect(described_class.run(["lib/app", "--baseline", "b.json"])).to(eq(2)) }
        .to(output(/b\.json is not a usable baseline/).to_stderr)
      expect { expect(described_class.run(%w[lib/app --update-baseline --baseline nope/b.json])).to(eq(2)) }
        .to(output(%r{cannot write nope/b\.json}).to_stderr)
    end
  end

  it "prints user-facing errors to stderr and exits 2 for misuse" do
    expect do
      expect(described_class.run(["missing_directory"])).to(eq(2))
    end.to(output("hashira: no such directory: missing_directory\n").to_stderr)
  end

  it "turns an unexpected failure into an exit 70 and a line worth reporting" do
    expect do
      expect(described_class.run([nil])).to(eq(70))
    end.to(output(%r{\Ahashira: internal error — \w+.*\n  at .*\n.*report it at https://}m).to_stderr)
  end
end
