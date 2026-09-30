# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Clones) do
  it "reports one finding per cluster, with each site as evidence and a refactoring" do
    duplication(Fixtures::DUPLICATION_FILES) do |clones|
      finding = clones.findings.first
      expect(clones.findings.size).to(eq(1))
      expect(finding.kind).to(eq("duplication"))
      expect(message(finding)).to(include("2 similar fragments"))
      expect(finding.evidence).to(
        include(
          a_string_matching(%r{orders/checkout\.rb:4-8}),
          a_string_matching(%r{billing/refund\.rb:4-8})
        )
      )
    end
  end

  it "finds no duplication in code that has none" do
    files = { "lib/app/solo/x.rb" => "module App\n module Solo\n class X\n def a = 1\n end\n end\n end\n" }
    duplication(files) { |clones| expect(clones.findings).to(be_empty) }
  end

  it "warns, via churn, when both sites of a clone change more often than the typical file" do
    duplication(Fixtures::DUPLICATION_FILES) do |clones|
      churn = Hashira::Churn.new("orders/checkout.rb" => 5, "billing/refund.rb" => 4, "quiet.rb" => 1, "still.rb" => 1)
      finding = Hashira::Duplication::DuplicationFinding.new(clones.clusters.first, churn).to_finding
      expect(message(finding)).to(include("Both sites change often"))
    end
  end

  it "keys a clone by a digest that survives it moving down the file and changes when it changes" do
    digest = ->(files) { duplication(files) { |clones| return clones.findings.first.digest } }
    original = digest.call(Fixtures::DUPLICATION_FILES)
    moved = Fixtures::DUPLICATION_FILES.transform_values { "\n\n#{it}" }
    changed = Fixtures::DUPLICATION_FILES.transform_values { it.gsub("gateway.connect(", "gateway.reconnect(1, ") }
    expect(original).to(match(/\A\h{12}\z/))
    expect(digest.call(moved)).to(eq(original))
    expect(digest.call(changed)).not_to(eq(original))
  end
end
