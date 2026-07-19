# frozen_string_literal: true

RSpec.describe Hashira::Project do
  it "raises for a missing directory" do
    expect { described_class.new(["nope"]) }
      .to raise_error(Hashira::Error, "no such directory: nope")
  end

  it "strips trailing slashes from directories" do
    within_project("lib/app/a/x.rb" => "") do
      expect(described_class.new(["lib/app/"]).directories).to eq(["lib/app"])
    end
  end

  it "lists files sorted across directories" do
    files = { "lib/app/b/y.rb" => "", "lib/app/a/x.rb" => "", "extra/c/z.rb" => "" }
    within_project(files) do
      project = described_class.new(["lib/app", "extra"])
      expect(project.files).to eq(["extra/c/z.rb", "lib/app/a/x.rb", "lib/app/b/y.rb"])
    end
  end

  describe "#package_for" do
    it "uses the first folder under the target directory" do
      within_project("lib/app/alpha/deep/x.rb" => "") do
        expect(described_class.new(["lib/app"]).package_for("lib/app/alpha/deep/x.rb")).to eq("alpha")
      end
    end

    it "folds a root-level file into its sibling folder package" do
      within_project("lib/app/alpha.rb" => "", "lib/app/alpha/x.rb" => "") do
        expect(described_class.new(["lib/app"]).package_for("lib/app/alpha.rb")).to eq("alpha")
      end
    end

    it "puts a plain root-level file in the (root) package" do
      within_project("lib/app/loose.rb" => "") do
        expect(described_class.new(["lib/app"]).package_for("lib/app/loose.rb")).to eq("(root)")
      end
    end

    it "raises for a path outside the analyzed directories" do
      within_project("lib/app/a/x.rb" => "") do
        expect { described_class.new(["lib/app"]).package_for("other/x.rb") }
          .to raise_error(Hashira::Error, "other/x.rb is outside the analyzed directories")
      end
    end
  end

  describe "#relative" do
    it "strips the owning directory prefix" do
      within_project("lib/app/a/x.rb" => "") do
        expect(described_class.new(["lib/app"]).relative("lib/app/a/x.rb")).to eq("a/x.rb")
      end
    end
  end

  describe "#label" do
    it "joins the directories" do
      within_project("a/x.rb" => "", "b/y.rb" => "") do
        expect(described_class.new(%w[a b]).label).to eq("a, b")
      end
    end
  end

  describe ".detect" do
    it "uses explicit directories when given" do
      within_project("src/a/x.rb" => "") do
        expect(described_class.detect(["src"]).directories).to eq(["src"])
      end
    end

    it "auto-detects a single lib/<gem> directory" do
      within_project("lib/mygem/a/x.rb" => "") do
        expect(described_class.detect([]).directories).to eq(["lib/mygem"])
      end
    end

    it "falls back to lib when it has several subdirectories" do
      within_project("lib/one/x.rb" => "", "lib/two/y.rb" => "") do
        expect(described_class.detect([]).directories).to eq(["lib"])
      end
    end

    it "raises without a lib directory" do
      within_project({}) do
        expect { described_class.detect([]) }
          .to raise_error(Hashira::Error, %r{no lib/ directory here})
      end
    end
  end
end
