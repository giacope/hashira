# frozen_string_literal: true

RSpec.describe(Hashira::Report::HotspotTable, :aggregate_failures) do
  def cost(file, cognitive, duplication, churn)
    Hashira::Hotspots::FileCost.new(file:, cognitive:, duplication:, churn:)
  end

  def render(files, top: described_class::TOP, weighed: true)
    capture { described_class.new(instance_double(Hashira::Hotspots::Rollup, files:, weighed?: weighed), top:).print }
  end
  it "prints a ranked row per file, with a legend" do
    output = render([cost("orders/checkout.rb", 12, 40, 6), cost("billing/refund.rb", 3, 0, 2)])
    expect(output).to(eq(<<~TEXT))
      Hotspots — cost × churn (where refactoring pays the most):

      file                Cog  Dup  Churn  Rank
      -----------------------------------------
      orders/checkout.rb   12   40      6   312
      billing/refund.rb     3    0      2     6

      Legend: Cog cognitive complexity, Dup mass of the clones the file carries,
              Churn commits touching it, Rank (Cog+Dup) × Churn

    TEXT
  end

  it "shows only the worst files, and says how many it withheld" do
    output = render(Array.new(described_class::TOP + 3) { cost("f#{it}.rb", 5, 0, 1) })
    expect(output.lines.grep(/^f\d|… and/).last(2))
      .to(eq(["f9.rb    5    0      1     5\n", "#{Hashira::Report::Withheld.new(3)}\n"]))
  end

  it "says nothing about withheld rows when every file fits" do
    expect(render([cost("a.rb", 5, 0, 1)], top: 1)).not_to(include("more —"))
  end

  it "says the rank is the cost alone when no git history weighs it" do
    output = render([cost("orders/checkout.rb", 12, 40, 0)], weighed: false)
    expect(output.lines.values_at(0, -2)).to(
      eq(
        [
          "Hotspots — cost alone, no git history to weigh (where refactoring pays the most):\n",
          "        Churn commits touching it, Rank (Cog+Dup)\n"
        ]
      )
    )
  end

  it "prints nothing at all when no file costs anything" do
    expect(render([])).to(be_empty)
  end
end
