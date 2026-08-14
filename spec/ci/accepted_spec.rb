# frozen_string_literal: true

RSpec.describe(Hashira::CI::Accepted) do
  def finding(kind: "cycle", package: "app", digest: nil)
    Hashira::Analysis::Finding.new(kind:, package:, digest:, evidence: [])
  end

  def accepting(entry) = described_class.new([entry])

  def acceptance
    {
      version: 1, edges: [],
      accepted: [{ kind: "cycle", package: "app", reason: "usage conformance-tests the CLI" }]
    }
  end
  it "screens matching findings out with their reason" do
    within({}) do
      File.write("b.json", JSON.generate(acceptance))
      screened = described_class.build("b.json").screen([finding, finding(kind: "sdp_violation")])
      expect(screened.all.map(&:kind)).to(eq(%w[sdp_violation]))
      expect(screened.accepted).to(eq([[finding, "usage conformance-tests the CLI"]]))
    end
  end

  it "supplies a placeholder reason when none is recorded" do
    screened = described_class.new([{ "kind" => "cycle", "package" => "app" }]).screen([finding])
    expect(screened.accepted.first.last).to(eq("accepted (no reason recorded)"))
  end

  it "keeps a clone accepted by digest when its lines move" do
    entry = { "kind" => "duplication", "digest" => "a3f9c1", "reason" => "generated, both sides regenerate" }
    moved = finding(kind: "duplication", package: "orders.rb:91", digest: "a3f9c1")
    expect(accepting(entry).screen([moved]).all).to(be_empty)
  end

  it "refuses to accept a clone named by position, since the position is not its identity" do
    entry = { "kind" => "duplication", "package" => "orders.rb:4", "reason" => "generated" }
    clone = finding(kind: "duplication", package: "orders.rb:4", digest: "a3f9c1")
    expect(accepting(entry).screen([clone]).all.size).to(eq(1))
  end

  it "does not accept a different clone that happens to sit where an accepted one did" do
    entry = { "kind" => "duplication", "digest" => "a3f9c1", "reason" => "generated" }
    other = finding(kind: "duplication", package: "orders.rb:4", digest: "ffffff")
    expect(accepting(entry).screen([other]).all.size).to(eq(1))
  end

  it "screens nothing without a baseline file" do
    screened = described_class.build("nope.json").screen([finding])
    expect(screened.all.size).to(eq(1))
    expect(screened.accepted).to(be_empty)
  end
end
