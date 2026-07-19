# frozen_string_literal: true

RSpec.describe Hashira::CI::Accepted do
  def finding(kind: "cycle", package: "app")
    Hashira::Analysis::Finding.new(kind:, package:, message: "m", evidence: [])
  end

  it "screens matching findings out with their reason" do
    within_project({}) do
      File.write("b.json", JSON.generate(
                             version: 1, edges: [],
                             accepted: [{ kind: "cycle", package: "app",
                                          reason: "usage conformance-tests the CLI" }]
                           ))
      screened = described_class.load("b.json").screen([finding, finding(kind: "sdp_violation")])
      expect(screened.all.map(&:kind)).to eq(%w[sdp_violation])
      expect(screened.accepted).to eq([[finding, "usage conformance-tests the CLI"]])
    end
  end

  it "supplies a placeholder reason when none is recorded" do
    screened = described_class.new([{ "kind" => "cycle", "package" => "app" }])
                              .screen([finding])
    expect(screened.accepted.first.last).to eq("accepted (no reason recorded)")
  end

  it "screens nothing without a baseline file" do
    screened = described_class.load("nope.json").screen([finding])
    expect(screened.all.size).to eq(1)
    expect(screened.accepted).to be_empty
  end
end
