# frozen_string_literal: true

RSpec.describe(Hashira::Churn, :aggregate_failures) do
  def commit(message, *)
    git(*, "add", "-A")
    git(*, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", message)
  end

  it "counts hits by the exact display path" do
    churn = described_class.new("foo.rb" => 3, "bar.rb" => 1)
    expect(churn.hits("foo.rb")).to(eq(3))
    expect(churn.hits("missing.rb")).to(eq(0))
  end

  # A repository holding the files in one commit.
  def within_repository(files, *options)
    within(files) do
      git("init", "-q", *options)
      commit("x")
      yield
    end
  end

  def revise(*paths, message: "y")
    paths.each { File.write(it, "2\n") }
    commit(message)
  end

  def hits(directories, *files)
    churn = described_class.build(Hashira::Project.new(directories))
    files.map { churn.hits(it) }
  end

  it "charges a file its own commits, never a namesake's elsewhere in the repository" do
    within_repository("lib/app/base.rb" => "1\n", "lib/app/database.rb" => "1\n", "spec/app/base.rb" => "1\n") do
      revise("lib/app/database.rb", "spec/app/base.rb")
      expect(hits(["lib/app"], "base.rb", "database.rb")).to(eq([1, 2]))
    end
  end

  it "reads every analyzed directory, keyed by the path the report shows for each file" do
    within_repository(%w[app/models/user.rb lib/tools.rb app/shared.rb lib/shared.rb].to_h { [it, "1\n"] }) do
      revise("lib/tools.rb", "lib/shared.rb")
      expect(hits(%w[app lib], "app/models/user.rb", "lib/tools.rb", "lib/shared.rb", "app/shared.rb", "shared.rb"))
        .to(eq([1, 2, 2, 1, 0]))
      expect(hits(["app"], "models/user.rb")).to(eq([1]))
    end
  end

  def merged_side
    git("checkout", "-qb", "side")
    revise("lib/a.rb", message: "side")
    git("checkout", "-q", "main")
    revise("lib/a.rb", message: "main")
    git("-c", "user.email=t@t", "-c", "user.name=t", "merge", "-q", "--no-edit", "side")
  end

  it "counts a side branch's commit even when the merge leaves the directory as the main line had it" do
    within_repository({ "lib/a.rb" => "1\n" }, "-b", "main") do
      merged_side
      expect(hits(["lib"], "a.rb")).to(eq([3]))
    end
  end

  it "keeps a directory outside the repository from voiding the history of one inside it" do
    within("repo/a.rb" => "1\n", "loose/b.rb" => "1\n") do
      git("-C", "repo", "init", "-q")
      commit("x", "-C", "repo")
      expect(hits(%w[repo loose], "repo/a.rb", "loose/b.rb")).to(eq([1, 0]))
    end
  end

  it "tallies a rename as a delete and an add, never following the move" do
    within_repository("a.rb" => "class A\nend\n") do
      File.rename("a.rb", "b.rb")
      commit("y")
      expect(hits(["."], "a.rb", "b.rb")).to(eq([2, 1]))
    end
  end

  def depth = described_class.build(Hashira::Project.new(["lib/app"])).then { [it.history?, it.depth.to_h] }

  def depths
    thin = depth
    revise("lib/app/a.rb")
    git("clone", "-q", "--depth", "1", "file://#{Dir.pwd}", "cut")
    [thin, depth, Dir.chdir("cut") { [depth, hits(["lib/app"], "a.rb")] }]
  end

  it "weighs churn only with two commits or more of full history, and counts nothing a shallow clone holds" do
    found = within_repository("lib/app/a.rb" => "1\n") { depths }
    expect(found).to(
      eq(
        [
          [false, { commits: 1, shallow: false, deep: false }], [true, { commits: 2, shallow: false, deep: true }],
          [[false, { commits: 1, shallow: true, deep: false }], [0]]
        ]
      )
    )
  end

  it "reads the history of the analyzed directory, not the working directory" do
    within("repo/a.rb" => "class A\nend\n") do
      git("-C", "repo", "init", "-q")
      commit("x", "-C", "repo")
      expect([hits(["repo"], "a.rb"), described_class.build(Hashira::Project.new(["."])).history?]).to(eq([[1], false]))
    end
  end

  def quoted(quote_path, external)
    git("config", "core.quotepath", quote_path)
    with_default_encodings(external) { hits(["."], Dir["*.rb"].first) }
  end

  it "counts a file whose name is not ASCII, whatever git's quotepath or the locale's encoding" do
    within_repository("café.rb" => "class Café\nend\n") do
      expect(%w[true false].product([Encoding::UTF_8, Encoding::US_ASCII]).map { quoted(*it) }).to(eq([[1]] * 4))
    end
  end

  it "keys a non-ASCII directory's files by their full path when several directories are analyzed" do
    within_repository("café/a.rb" => "1\n", "lib/b.rb" => "1\n") do
      expect(hits(%w[café lib], "café/a.rb", "lib/b.rb")).to(eq([1, 1]))
    end
  end

  def without_git
    path = ENV.fetch("PATH", nil)
    ENV["PATH"] = ""
    yield
  ensure
    ENV["PATH"] = path
  end

  it "reports no history rather than crashing when git is not on PATH" do
    within("a.rb" => "class A\nend\n") do
      expect(without_git { described_class.build(Hashira::Project.new(["."])).history? }).to(be(false))
    end
  end

  def sites(*files) = files.map { instance_double(Hashira::Duplication::Fragment, file: it) }

  it "is hot only when two distinct files both change more than the typical file" do
    churn = described_class.new("a.rb" => 5, "b.rb" => 3, "c.rb" => 2, "d.rb" => 1, "e.rb" => 1)
    expect(churn.hot?(sites("a.rb", "b.rb"))).to(be(true))
    expect(churn.hot?(sites("a.rb", "c.rb"))).to(be(false))
    expect(churn.hot?(sites("a.rb", "a.rb", "d.rb"))).to(be(false))
  end

  it "calls a file busy only above the median, so a history where every file changes once has no hot clone" do
    expect(described_class.new("a.rb" => 1, "b.rb" => 1).hot?(sites("a.rb", "b.rb"))).to(be(false))
    expect(
      described_class.new(
        "a.rb" => 3, "b.rb" => 3, "c.rb" => 1,
        "d.rb" => 1
      ).hot?(sites("a.rb", "b.rb"))
    ).to(be(true))
    expect(described_class.new({}).hot?(sites("a.rb", "b.rb"))).to(be(false))
  end
end
