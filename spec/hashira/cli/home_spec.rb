# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Home, :aggregate_failures) do
  def home(directories) = described_class.build(directories)

  it "is where hashira runs when no directory is named" do
    within("lib/app/x.rb" => "") { expect(home([]).path).to(eq(Dir.pwd)) }
  end

  it "is the nearest folder above the directory that holds hashira's own files" do
    files = {
      "tool/hashira_baseline.json" => "{}", "proj/.hashira.yml" => "", "proj/lib/app/x.rb" => "",
      "proj/Gemfile" => ""
    }
    within(files) do
      Dir.chdir("tool") { expect(home(["../proj/lib/app"]).path).to(eq(File.expand_path("../proj"))) }
    end
  end

  it "stops where hashira runs when no project root sits between it and the directory" do
    within("lib/app/x.rb" => "", "Gemfile" => "") { expect(home(["lib/app"]).path).to(eq(Dir.pwd)) }
  end

  it "stops at the first project root above the directory, never reading an enclosing project's files" do
    files = {
      ".hashira.yml" => "", "hashira_baseline.json" => "{}", "vendor/gem/.git/HEAD" => "",
      "vendor/gem/lib/x.rb" => "", "vendor/app/Gemfile" => "", "vendor/app/lib/y.rb" => "",
      "vendor/kit/kit.gemspec" => "", "vendor/kit/lib/z.rb" => ""
    }
    within(files) do
      expect(%w[gem app kit].map { home(["vendor/#{it}/lib"]).path })
        .to(eq(%w[gem app kit].map { File.expand_path("vendor/#{it}") }))
      Dir.chdir("vendor/gem") { expect(home(["lib"]).path).to(eq(Dir.pwd)) }
    end
  end

  it "is the project that holds every directory named, whatever their order" do
    files = {
      "repo/.git/HEAD" => "", "repo/core/core.gemspec" => "", "repo/core/lib/x.rb" => "",
      "repo/support/support.gemspec" => "", "repo/support/lib/y.rb" => ""
    }
    within(files) do
      found = [%w[repo/core/lib repo/support/lib], %w[repo/support/lib repo/core/lib], %w[repo/support/lib]]
      expect(found.map { home(it).path }).to(eq(%w[repo repo repo/support].map { File.expand_path(it) }))
    end
  end

  it "climbs to the project's markers from outside it, then to the folder holding lib" do
    files = { "proj/Gemfile" => "", "proj/lib/app/x.rb" => "", "bare/lib/x/y.rb" => "", "here/README" => "" }
    within(files) do
      paths = Dir.chdir("here") { %w[../proj/lib/app ../bare/lib/x ../proj/lib/app].map { home([it]).path } }
      expect(paths).to(eq(%w[proj bare proj].map { File.expand_path(it) }))
    end
  end

  def placed(found) = [found.join("b.json"), found.expand("ci/b.json"), found.relative("../proj/lib")]

  it "names files plainly when home is where hashira runs, and in full otherwise" do
    within("proj/.git/HEAD" => "", "proj/lib/x.rb" => "", "here/README" => "") do
      named = Dir.chdir("here") { placed(home(["../proj/lib"])) }
      expect(named).to(eq([File.expand_path("proj/b.json"), File.expand_path("proj/ci/b.json"), "lib"]))
      expect([home([]).join("b.json"), home([]).expand("ci/b.json")]).to(eq(["b.json", "ci/b.json"]))
    end
  end
end
