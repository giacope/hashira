# frozen_string_literal: true

RSpec.describe(Hashira::Churn) do
  it "tallies file paths from git log output, ignoring blank lines" do
    expect(described_class.tally("a.rb\nb.rb\n\na.rb\n")).to(eq("a.rb" => 2, "b.rb" => 1))
  end
  it "counts hits by matching a display path against the git-path suffix" do
    churn = described_class.new("lib/app/foo.rb" => 3, "lib/app/bar.rb" => 1)
    expect(churn.hits("foo.rb")).to(eq(3))
    expect(churn.hits("missing.rb")).to(eq(0))
  end
  it "tallies a rename as a delete and an add, never following the move" do
    within("a.rb" => "class A\nend\n") do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      File.rename("a.rb", "b.rb")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "y")
      churn = described_class.scan(".")
      expect(churn.hits("a.rb")).to(eq(2))
      expect(churn.hits("b.rb")).to(eq(1))
    end
  end
  it "reads the history of the analyzed directory, not the working directory" do
    within("repo/a.rb" => "class A\nend\n") do
      git("-C", "repo", "init", "-q")
      git("-C", "repo", "add", "-A")
      git("-C", "repo", "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      expect(described_class.scan("repo").hits("a.rb")).to(eq(1))
      expect(described_class.scan(".").history?).to(be(false))
    end
  end
  it "reports no history rather than crashing when git is not on PATH" do
    within("a.rb" => "class A\nend\n") do
      path = ENV.fetch("PATH", nil)
      ENV["PATH"] = ""
      expect(described_class.scan(".").history?).to(be(false))
    ensure
      ENV["PATH"] = path
    end
  end
  it "is hot only when at least two sites sit in changed files" do
    churn = described_class.new("a.rb" => 5, "b.rb" => 2)
    sites = [
      instance_double(Hashira::Duplication::Fragment, file: "a.rb"),
      instance_double(Hashira::Duplication::Fragment, file: "b.rb")
    ]
    expect(churn.hot?(sites)).to(be(true))
    expect(described_class.new("a.rb" => 5).hot?(sites)).to(be(false))
  end
end
