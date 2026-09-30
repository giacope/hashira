# frozen_string_literal: true

RSpec.describe(Hashira::Churn) do
  def commit(message, *)
    git(*, "add", "-A")
    git(*, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", message)
  end

  it "counts hits by the exact display path" do
    churn = described_class.new("foo.rb" => 3, "bar.rb" => 1)
    expect(churn.hits("foo.rb")).to(eq(3))
    expect(churn.hits("missing.rb")).to(eq(0))
  end

  it "charges a file its own commits, never a namesake's elsewhere in the repository" do
    within("lib/app/base.rb" => "1\n", "lib/app/database.rb" => "1\n", "spec/app/base.rb" => "1\n") do
      git("init", "-q")
      commit("x")
      File.write("lib/app/database.rb", "2\n")
      File.write("spec/app/base.rb", "2\n")
      commit("y")
      churn = described_class.build(["lib/app"])
      expect(churn.hits("base.rb")).to(eq(1))
      expect(churn.hits("database.rb")).to(eq(2))
    end
  end

  it "reads every analyzed directory, each path relative to its own directory" do
    within(
      "app/models/user.rb" => "1\n", "lib/tools.rb" => "1\n", "app/shared.rb" => "1\n",
      "lib/shared.rb" => "1\n"
    ) do
      git("init", "-q")
      commit("x")
      File.write("lib/tools.rb", "2\n")
      File.write("lib/shared.rb", "2\n")
      commit("y")
      churn = described_class.build(%w[app lib])
      expect(churn.hits("models/user.rb")).to(eq(1))
      expect(churn.hits("tools.rb")).to(eq(2))
      expect(churn.hits("shared.rb")).to(eq(2))
      expect(described_class.build(%w[lib app]).hits("shared.rb")).to(eq(2))
    end
  end

  it "keeps a directory outside the repository from voiding the history of one inside it" do
    within("repo/a.rb" => "1\n", "loose/b.rb" => "1\n") do
      git("-C", "repo", "init", "-q")
      commit("x", "-C", "repo")
      churn = described_class.build(%w[repo loose])
      expect(churn.hits("a.rb")).to(eq(1))
      expect(churn.hits("b.rb")).to(eq(0))
    end
  end

  it "tallies a rename as a delete and an add, never following the move" do
    within("a.rb" => "class A\nend\n") do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      File.rename("a.rb", "b.rb")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "y")
      churn = described_class.build(["."])
      expect(churn.hits("a.rb")).to(eq(2))
      expect(churn.hits("b.rb")).to(eq(1))
    end
  end

  it "reads the history of the analyzed directory, not the working directory" do
    within("repo/a.rb" => "class A\nend\n") do
      git("-C", "repo", "init", "-q")
      git("-C", "repo", "add", "-A")
      git("-C", "repo", "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      expect(described_class.build(["repo"]).hits("a.rb")).to(eq(1))
      expect(described_class.build(["."]).history?).to(be(false))
    end
  end

  it "counts a file whose name is not ASCII, whatever git's quotepath or the locale's encoding" do
    within("café.rb" => "class Café\nend\n") do
      git("init", "-q")
      git("add", "-A")
      git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "x")
      %w[true false].product([Encoding::UTF_8, Encoding::US_ASCII]).each do |quote_path, external|
        git("config", "core.quotepath", quote_path)
        with_default_encodings(external) do
          expect(described_class.build(["."]).hits(Dir["*.rb"].first)).to(eq(1))
        end
      end
    end
  end

  it "reports no history rather than crashing when git is not on PATH" do
    within("a.rb" => "class A\nend\n") do
      path = ENV.fetch("PATH", nil)
      ENV["PATH"] = ""
      expect(described_class.build(["."]).history?).to(be(false))
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
