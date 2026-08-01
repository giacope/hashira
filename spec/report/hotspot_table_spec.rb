# frozen_string_literal: true

RSpec.describe(Hashira::Report::HotspotTable) do
  def cost(file, cognitive, duplication, churn)
    Hashira::Hotspots::FileCost.new(file:, cognitive:, duplication:, churn:)
  end

  def render(files)
    capture { described_class.new(instance_double(Hashira::Hotspots::Rollup, files:)).print }
  end
  it "prints a ranked row per file, with a legend" do
    output = render([cost("orders/checkout.rb", 12, 40, 6), cost("billing/refund.rb", 3, 0, 2)])
    expect(output).to(include("Hotspots — cost × churn", "orders/checkout.rb", "312", "billing/refund.rb", "Legend:"))
  end
  it "shows only the worst files" do
    output = render(Array.new(described_class::TOP + 3) { cost("f#{it}.rb", 5, 0, 1) })
    expect(output.scan(/^f\d+\.rb/).size).to(eq(described_class::TOP))
  end
  it "prints nothing at all when no file costs anything" do
    expect(render([])).to(be_empty)
  end
end
