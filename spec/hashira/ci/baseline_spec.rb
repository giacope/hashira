# frozen_string_literal: true

RSpec.describe(Hashira::CI::Baseline, :aggregate_failures) do
  def boundary
    {
      "root" => "Prism", "role" => "interpreted_model",
      "entrypoint" => "lib/app/trees.rb", "reason" => "the AST is the input model"
    }
  end

  def acceptance
    { "kind" => "feature_envy", "package" => "Café::Menú#total", "reason" => "reads its order — by design" }
  end

  def envy = Hashira::CI::Marks.new("feature_envy:Café::Menú#total" => 3)

  describe "#history" do
    it "holds no edges when the file is absent" do
      within({}) do
        expect(described_class.new("hashira_baseline.json").history.drift([])).to(be_empty)
      end
    end
  end

  describe "#accepted" do
    it "reads a baseline it can read, and an absent one as nothing accepted" do
      within("b.json" => %({"version": 3})) do
        expect(%w[b.json absent.json].map { described_class.new(it).accepted.to_h }).to(eq([{}, {}]))
      end
    end

    it "names the file and the reason when the JSON is malformed" do
      within("b.json" => "<<<<<<< HEAD\n{}\n") do
        expect { described_class.new("b.json").accepted }.to(
          raise_error(Hashira::Error, /\Ab\.json is not a usable baseline — .+Re-record it with --update-baseline\z/)
        )
      end
    end

    it "reports a baseline whose top level is a list" do
      within("b.json" => "[]\n") do
        expect { described_class.new("b.json").accepted }.to(
          raise_error(Hashira::Error, /its top level is a list, not an object/)
        )
      end
    end

    it "reports a directory standing where the baseline should be" do
      within("b.json/keep" => "") do
        expect { described_class.new("b.json").accepted }.to(raise_error(Hashira::Error, /is not a usable baseline/))
      end
    end
  end

  describe "under a locale that is not UTF-8" do
    it "reads a baseline whose text is not ASCII" do
      within("b.json" => JSON.generate(accepted: [acceptance])) do
        accepted = with_default_encodings(Encoding::US_ASCII) { described_class.new("b.json").accepted.to_h }
        expect(accepted).to(eq(accepted: [acceptance.transform_keys(&:to_sym)]))
      end
    end

    it "writes UTF-8 rather than transcoding to the locale's encoding" do
      within({}) do
        baseline = described_class.new("b.json")
        with_default_encodings(Encoding::US_ASCII, Encoding::UTF_8) { baseline.write([], envy, packaging: "folder") }
        expect(File.binread("b.json")).to(include("Café::Menú#total".b))
      end
    end
  end

  it "writes no traces section when no finding carries a trace" do
    within({}) do
      marks = Hashira::CI::Marks.new("dupe:a3" => 30)
      described_class.new("b.json").write([], marks, packaging: "folder")
      expect(JSON.parse(File.read("b.json")).keys).to(eq(%w[version packaging analyzers targets edges findings]))
    end
  end

  it "preserves declared boundaries when it is rewritten" do
    within("b.json" => JSON.generate(boundaries: [boundary])) do
      described_class.new("b.json").write([], Hashira::CI::Marks.new, packaging: "folder")
      expect(JSON.parse(File.read("b.json"))["boundaries"]).to(eq([boundary]))
    end
  end
end
