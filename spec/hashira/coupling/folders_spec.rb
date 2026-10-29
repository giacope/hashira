# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Folders, :aggregate_failures) do
  def folders(directories) = described_class.new(Hashira::Project.new(directories).paths)

  it "uses the first folder under the target directory" do
    within("lib/app/alpha/deep/x.rb" => "", "lib/app/beta/y.rb" => "") do
      expect(folders(["lib/app"]).package("lib/app/alpha/deep/x.rb")).to(eq("alpha"))
    end
  end

  it "folds a root-level file into its sibling folder package" do
    within("lib/app/alpha.rb" => "", "lib/app/alpha/x.rb" => "") do
      expect(folders(["lib/app"]).package("lib/app/alpha.rb")).to(eq("alpha"))
    end
  end

  it "puts a plain root-level file in the (root) package" do
    within("lib/app/loose.rb" => "") do
      expect(folders(["lib/app"]).package("lib/app/loose.rb")).to(eq("(root)"))
    end
  end

  it "qualifies same-named folders from different directories with their root" do
    files = { "app/models/x.rb" => "", "lib/models/y.rb" => "", "lib/views/z.rb" => "" }
    within(files) do
      folders = folders(%w[app lib])
      expect(files.keys.map { folders.package(it) }).to(eq(%w[app/models lib/models views]))
    end
  end

  it "keeps each directory's loose files in a root package of its own when several are analyzed" do
    within("app/loose.rb" => "", "lib/stray.rb" => "", "lib/tools/y.rb" => "") do
      folders = folders(%w[app lib])
      expect(%w[app/loose.rb lib/stray.rb lib/tools/y.rb].map { folders.package(it) })
        .to(eq(%w[app/(root) lib/(root) tools]))
    end
  end

  it "raises for a path outside the analyzed directories" do
    within("lib/app/a/x.rb" => "") do
      expect { folders(["lib/app"]).package("other/x.rb") }
        .to(raise_error(Hashira::Error, "other/x.rb is outside the analyzed directories"))
    end
  end
end
