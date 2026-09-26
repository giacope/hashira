# frozen_string_literal: true

RSpec.describe(Hashira::CI::Baseline) do
  def boundary
    {
      "root" => "Prism", "role" => "interpreted_model",
      "entrypoint" => "lib/app/trees.rb", "reason" => "the AST is the input model"
    }
  end

  describe "#edges" do
    it "returns nothing recorded when the file is absent" do
      within({}) do
        expect(described_class.new("hashira_baseline.json").edges).to(eq([]))
      end
    end
  end

  describe "#trouble" do
    it "stays quiet for a baseline it can read" do
      within("b.json" => %({"version": 3})) do
        expect(described_class.new("b.json").trouble).to(be_nil)
        expect(described_class.new("absent.json").trouble).to(be_nil)
      end
    end

    it "names the file and the reason when the JSON is malformed" do
      within("b.json" => "<<<<<<< HEAD\n{}\n") do
        expect(described_class.new("b.json").trouble)
          .to(match(/\Ab\.json is not a usable baseline — .+Re-record it with --update-baseline\z/))
      end
    end

    it "reports a baseline whose top level is a list" do
      within("b.json" => "[]\n") do
        expect(described_class.new("b.json").trouble).to(include("its top level is a list, not an object"))
      end
    end

    it "reports a directory standing where the baseline should be" do
      within("b.json/keep" => "") do
        expect(described_class.new("b.json").trouble).to(include("is not a usable baseline"))
      end
    end
  end

  it "writes no traces section when no finding carries a trace" do
    within({}) do
      marks = { "dupe:a3" => Hashira::CI::Mark.new(magnitude: 30, trace: nil) }
      described_class.new("b.json").write([], marks, packaging: "folder")
      expect(JSON.parse(File.read("b.json")).keys).to(eq(%w[version packaging analyzers targets edges findings]))
    end
  end

  it "preserves declared boundaries when it is rewritten" do
    within("b.json" => JSON.generate(boundaries: [boundary])) do
      described_class.new("b.json").write([], {}, packaging: "folder")
      expect(JSON.parse(File.read("b.json"))["boundaries"]).to(eq([boundary]))
    end
  end
end
