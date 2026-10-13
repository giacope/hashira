# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Home) do
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

  it "stays where hashira runs when that folder holds the directory and no hashira file sits between" do
    within("lib/app/x.rb" => "", "lib/Gemfile" => "") { expect(home(["lib/app"]).path).to(eq(Dir.pwd)) }
  end

  it "climbs to the project's markers from outside it, then to the folder holding lib" do
    files = { "proj/Gemfile" => "", "proj/lib/app/x.rb" => "", "bare/lib/x/y.rb" => "", "here/README" => "" }
    within(files) do
      Dir.chdir("here") do
        expect(home(["../proj/lib/app"]).path).to(eq(File.expand_path("../proj")))
        expect(home(["../bare/lib/x"]).path).to(eq(File.expand_path("../bare")))
        expect(home(["../proj/lib/app"]).path).to(eq(File.expand_path("../proj")))
      end
    end
  end

  it "names files plainly when home is where hashira runs, and in full otherwise" do
    within("proj/.git/HEAD" => "", "proj/lib/x.rb" => "", "here/README" => "") do
      Dir.chdir("here") do
        found = home(["../proj/lib"])
        expect(found.join("b.json")).to(eq(File.expand_path("../proj/b.json")))
        expect(found.expand("ci/b.json")).to(eq(File.expand_path("../proj/ci/b.json")))
        expect(found.relative("../proj/lib")).to(eq("lib"))
      end
      expect(home([]).join("b.json")).to(eq("b.json"))
      expect(home([]).expand("ci/b.json")).to(eq("ci/b.json"))
    end
  end
end
