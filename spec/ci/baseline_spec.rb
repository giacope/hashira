# frozen_string_literal: true

RSpec.describe(Hashira::CI::Baseline) do
  describe ".read" do
    it "returns nothing recorded when the file is absent" do
      within({}) do
        expect(described_class.read("hashira_baseline.json")).to(eq({}))
      end
    end
  end
  describe ".trouble" do
    it "stays quiet for a baseline it can read" do
      within("b.json" => %({"version": 3})) do
        expect(described_class.trouble("b.json")).to(be_nil)
        expect(described_class.trouble("absent.json")).to(be_nil)
      end
    end
    it "names the file and the reason when the JSON is malformed" do
      within("b.json" => "<<<<<<< HEAD\n{}\n") do
        expect(described_class.trouble("b.json"))
          .to(match(/\Ab\.json is not a usable baseline — .+Re-record it with --update-baseline\z/))
      end
    end
    it "reports a baseline whose top level is a list" do
      within("b.json" => "[]\n") do
        expect(described_class.trouble("b.json")).to(include("its top level is a list, not an object"))
      end
    end
    it "reports a directory standing where the baseline should be" do
      within("b.json/keep" => "") do
        expect(described_class.trouble("b.json")).to(include("is not a usable baseline"))
      end
    end
  end
end
