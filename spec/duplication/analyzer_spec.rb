# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Analyzer) do
  it "reports one finding per cluster, with each site as evidence and a refactoring" do
    duplication(FixtureHelper::DUPLICATION_FILES) do |analyzer|
      finding = analyzer.findings.first
      expect(analyzer.findings.size).to(eq(1))
      expect(finding.kind).to(eq("duplication"))
      expect(finding.message).to(include("2 similar fragments"))
      expect(finding.evidence).to(
        include(
          a_string_matching(%r{orders/checkout\.rb:1-11}),
          a_string_matching(%r{billing/refund\.rb:1-11})
        )
      )
    end
  end
  it "finds no duplication in code that has none" do
    files = { "lib/app/solo/x.rb" => "module App\n module Solo\n class X\n def a = 1\n end\n end\n end\n" }
    duplication(files) { |analyzer| expect(analyzer.findings).to(be_empty) }
  end
  it "warns, via churn, when both sites of a clone change often" do
    duplication(FixtureHelper::DUPLICATION_FILES) do |analyzer|
      churn = Hashira::Churn.new("orders/checkout.rb" => 5, "billing/refund.rb" => 4)
      finding = Hashira::Duplication::DuplicationFinding.new(analyzer.clusters.first, churn).to_finding
      expect(finding.message).to(include("Both sites change often"))
    end
  end
end
