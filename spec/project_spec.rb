# frozen_string_literal: true

RSpec.describe(Hashira::Project) do
  it "raises for a missing directory" do
    expect { described_class.new(["nope"]).directories }.to(raise_error(Hashira::Error, "no such directory: nope"))
  end

  describe "when handed a file" do
    def refusal(requested)
      described_class.new(requested).directories
    rescue Hashira::Error => error
      error.message
    end

    it "suggests the default run focused on that file when the default run reads it" do
      within("lib/app.rb" => "", "lib/app/a/x.rb" => "") do
        expect(refusal(["./lib/app/a/x.rb"]))
          .to(eq("lib/app/a/x.rb is a file — hashira takes directories (try: hashira --only lib/app/a/x.rb)"))
      end
    end

    it "keeps the whole Rails application in the suggestion" do
      within("config/application.rb" => "", "app/models/problem.rb" => "", "app/models/user.rb" => "") do
        expect(refusal(%w[app/models/problem.rb app/models/user.rb]))
          .to(end_with("(try: hashira --only app/models/problem.rb,app/models/user.rb)"))
      end
    end

    it "names the enclosing top-level folder when the default run would not read the file" do
      gem = { "lib/gem.rb" => "", "lib/gem/a.rb" => "", "lib/generators/g.rb" => "" }
      within(gem.merge("script/s.rb" => "", "x.rb" => "")) do
        expect(refusal(["lib/generators/g.rb"])).to(end_with("(try: hashira lib --only lib/generators/g.rb)"))
        expect(refusal(%w[script/s.rb x.rb])).to(end_with("(try: hashira script . --only script/s.rb,x.rb)"))
      end
    end
  end

  it "counts a directory named twice, or by two spellings, only once" do
    within("lib/app/a/x.rb" => "") do
      expect(described_class.new(%w[lib/app lib/app]).directories).to(eq(["lib/app"]))
      expect(described_class.new(["lib/app", "./lib/app"]).directories).to(eq(["lib/app"]))
      expect(described_class.new(%w[lib/app lib/app]).files).to(eq(["lib/app/a/x.rb"]))
    end
  end

  it "drops a directory already covered by another argument" do
    within("lib/app/a/x.rb" => "") do
      expect(described_class.new(%w[lib/app lib/app/a]).directories).to(eq(["lib/app"]))
    end
  end

  it "raises for a directory holding no Ruby files" do
    within("lib/app/README.md" => "") do
      expect { described_class.new(["lib/app"]).files }.to(raise_error(Hashira::Error, "no Ruby files under lib/app"))
    end
  end

  it "strips trailing slashes from directories" do
    within("lib/app/a/x.rb" => "") do
      expect(described_class.new(["lib/app/"]).directories).to(eq(["lib/app"]))
    end
  end

  it "lists files sorted across directories" do
    files = { "lib/app/b/y.rb" => "", "lib/app/a/x.rb" => "", "extra/c/z.rb" => "" }
    within(files) do
      project = described_class.new(["lib/app", "extra"])
      expect(project.files).to(eq(["extra/c/z.rb", "lib/app/a/x.rb", "lib/app/b/y.rb"]))
    end
  end

  describe "#package" do
    it "uses the first folder under the target directory" do
      within("lib/app/alpha/deep/x.rb" => "", "lib/app/beta/y.rb" => "") do
        expect(described_class.new(["lib/app"]).package("lib/app/alpha/deep/x.rb")).to(eq("alpha"))
      end
    end

    it "folds a root-level file into its sibling folder package" do
      within("lib/app/alpha.rb" => "", "lib/app/alpha/x.rb" => "") do
        expect(described_class.new(["lib/app"]).package("lib/app/alpha.rb")).to(eq("alpha"))
      end
    end

    it "puts a plain root-level file in the (root) package" do
      within("lib/app/loose.rb" => "") do
        expect(described_class.new(["lib/app"]).package("lib/app/loose.rb")).to(eq("(root)"))
      end
    end

    it "qualifies same-named folders from different directories with their root" do
      files = { "app/models/x.rb" => "", "lib/models/y.rb" => "", "lib/views/z.rb" => "" }
      within(files) do
        project = described_class.new(%w[app lib])
        expect(project.package("app/models/x.rb")).to(eq("app/models"))
        expect(project.package("lib/models/y.rb")).to(eq("lib/models"))
        expect(project.package("lib/views/z.rb")).to(eq("views"))
      end
    end

    it "keeps each directory's loose files in a root package of its own when several are analyzed" do
      within("app/loose.rb" => "", "lib/stray.rb" => "", "lib/tools/y.rb" => "") do
        project = described_class.new(%w[app lib])
        expect(project.package("app/loose.rb")).to(eq("app/(root)"))
        expect(project.package("lib/stray.rb")).to(eq("lib/(root)"))
        expect(project.package("lib/tools/y.rb")).to(eq("tools"))
      end
    end

    it "raises for a path outside the analyzed directories" do
      within("lib/app/a/x.rb" => "") do
        expect { described_class.new(["lib/app"]).package("other/x.rb") }
          .to(raise_error(Hashira::Error, "other/x.rb is outside the analyzed directories"))
      end
    end
  end

  describe "#relative" do
    it "strips the owning directory prefix when one directory is analyzed" do
      within("lib/app/a/x.rb" => "") do
        expect(described_class.new(["lib/app"]).relative("lib/app/a/x.rb")).to(eq("a/x.rb"))
      end
    end

    it "names every file from the working directory when several are analyzed, so no two files share a name" do
      within("gem_a/lib/base.rb" => "", "gem_b/lib/base.rb" => "") do
        project = described_class.new(["gem_a/lib", "#{Dir.pwd}/gem_b/lib/"])
        expect(project.directories).to(eq(%w[gem_a/lib gem_b/lib]))
        expect(project.files.map { project.relative(it) }).to(eq(%w[gem_a/lib/base.rb gem_b/lib/base.rb]))
      end
    end

    it "raises for a path outside the analyzed directories" do
      within("a/x.rb" => "", "b/y.rb" => "") do
        expect { described_class.new(%w[a b]).relative("c/z.rb") }
          .to(raise_error(Hashira::Error, "c/z.rb is outside the analyzed directories"))
      end
    end
  end

  describe "#label" do
    it "joins the directories" do
      within("a/x.rb" => "", "b/y.rb" => "") do
        expect(described_class.new(%w[a b]).label).to(eq("a, b"))
      end
    end
  end

  describe "directory resolution" do
    it "uses explicit directories when given" do
      within("src/a/x.rb" => "") do
        expect(described_class.new(["src"]).directories).to(eq(["src"]))
      end
    end

    it "auto-detects a single lib/<gem> directory" do
      within("lib/mygem/a/x.rb" => "") do
        expect(described_class.new([]).directories).to(eq(["lib/mygem"]))
      end
    end

    it "descends a chain of single-folder wrappers to the package level" do
      files = { "lib/mygem/core/a/x.rb" => "", "lib/mygem/core/b/y.rb" => "", "lib/mygem/core.rb" => "" }
      within(files) do
        expect(described_class.new([]).directories).to(eq(["lib/mygem/core"]))
        expect(described_class.new(["lib"]).directories).to(eq(["lib/mygem/core"]))
      end
    end

    it "descends only when a single directory is analyzed, so several keep the same granularity" do
      files = {
        "one/lib/one/a/x.rb" => "", "one/lib/one/b/y.rb" => "", "two/lib/two/a/x.rb" => "",
        "two/lib/other.rb" => ""
      }
      within(files) do
        expect(described_class.new(%w[one/lib two/lib]).directories).to(eq(%w[one/lib two/lib]))
        expect(described_class.new(%w[one/lib one/lib/one]).directories).to(eq(%w[one/lib/one]))
      end
    end

    it "auto-detects lib/<gem> beside lib/<gem>.rb, even when lib/ holds sibling folders" do
      within("lib/gem.rb" => "", "lib/gem/a/x.rb" => "", "lib/gem/b/y.rb" => "", "lib/generators/g.rb" => "") do
        expect(described_class.new([]).directories).to(eq(["lib/gem"]))
      end
    end

    it "prefers the library the gemspec names when lib/ holds several" do
      files = {
        "lib/gem.rb" => "", "lib/gem/a/x.rb" => "", "lib/gem/b/y.rb" => "", "lib/ext.rb" => "",
        "lib/ext/z.rb" => ""
      }
      within(files.merge("gem.gemspec" => "")) do
        expect(described_class.new([]).directories).to(eq(["lib/gem"]))
      end
      within(files.merge("other.gemspec" => "")) do
        expect(described_class.new([]).directories).to(eq(["lib"]))
      end
    end

    it "reads app and lib in a Rails root, whichever exist" do
      within("config/application.rb" => "", "app/models/user.rb" => "", "lib/tools/x.rb" => "") do
        expect(described_class.new([]).directories).to(eq(%w[app lib]))
      end
      within("config/application.rb" => "", "app/models/user.rb" => "", "app/models/post.rb" => "") do
        expect(described_class.new([]).directories).to(eq(["app"]))
      end
    end

    it "stops descending at loose code files beside the single folder" do
      files = { "src/app/a/x.rb" => "", "src/app/b/y.rb" => "", "src/loose.rb" => "" }
      within(files) do
        expect(described_class.new(["src"]).directories).to(eq(["src"]))
      end
    end

    it "falls back to lib when it has several subdirectories" do
      within("lib/one/x.rb" => "", "lib/two/y.rb" => "") do
        expect(described_class.new([]).directories).to(eq(["lib"]))
      end
    end

    it "raises without a lib directory" do
      within({}) do
        expect { described_class.new([]).directories }.to(raise_error(Hashira::Error, %r{no lib/ directory here}))
      end
    end

    it "accepts a lib holding only loose files, as every gem does on day one" do
      within("lib/solo.rb" => "class Solo; def a = 1; end\n") do
        expect(described_class.new([]).directories).to(eq(["lib"]))
      end
    end
  end
end
