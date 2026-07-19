# frozen_string_literal: true

RSpec.describe Hashira::Analysis::Census do
  it "infers the most common outermost module as the root namespace" do
    analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
      expect(census.root_namespace).to eq("App")
    end
  end

  it "has no root namespace when the tree defines no types" do
    analyze({ "lib/app/empty/notes.rb" => "# just a comment\n" }) do |_project, census, _graph|
      expect(census.root_namespace).to be_nil
    end
  end

  it "counts only classes with direct method definitions as types" do
    files = {
      "lib/app/alpha/one.rb" => <<~RUBY,
        module App
          module Alpha
            class One
              def call = 1
            end

            class Two
              def call = 2
              def other = 3
            end

            module EmptyWrapper
            end
          end
        end
      RUBY
      "lib/app/beta/none.rb" => "module App; module Beta; end; end\n"
    }
    analyze(files) do |_project, census, _graph|
      expect(census.type_count).to eq("alpha" => 2)
      expect(census.packages).to contain_exactly("alpha", "beta")
    end
  end

  it "records a depth-1 module with only direct methods (no nested types)" do
    files = { "lib/app/flat/flat.rb" => "module App; module Flat; def self.x = 1; end; end\n" }
    analyze(files) do |_project, census, _graph|
      expect(census.declaring_package).to eq("Flat" => "flat")
    end
  end

  it "records the declaring package of each depth-1 constant" do
    analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
      expect(census.declaring_package)
        .to eq("Alpha" => "alpha", "Beta" => "beta", "Core" => "core")
    end
  end

  it "records top-level constants outside the root namespace" do
    files = FixtureHelper::CYCLIC_FILES.merge(
      "lib/app/helpers/extra.rb" => "module AppHelpers; class Extra; def a = 1; end; end\n"
    )
    analyze(files) do |_project, census, _graph|
      expect(census.declaring_package).to include("AppHelpers" => "helpers")
      expect(census.resolve(%w[AppHelpers Extra])).to eq("helpers")
    end
  end

  describe "#resolve" do
    it "resolves with and without the leading root namespace" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
        expect(census.resolve(%w[App Alpha One])).to eq("alpha")
        expect(census.resolve(%w[Alpha One])).to eq("alpha")
      end
    end

    it "returns nil for external constants" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
        expect(census.resolve(%w[JSON])).to be_nil
        expect(census.resolve([])).to be_nil
      end
    end
  end
end
