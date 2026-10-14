# frozen_string_literal: true

RSpec.describe(Hashira::Analysis) do
  it "counts a gem Ruby ships bundled as standard library, wherever it is installed" do
    expect(%w[csv bigdecimal rack].map { described_class::LIBRARIES.include?(it) }).to(eq([true, true, false]))
  end

  it "reads what a bare Ruby ships, not what this process happens to have loaded" do
    loaded = [described_class::CORE.include?("RSpec"), described_class::UNIVERSAL.include?(:to_json)]
    expect(loaded).to(eq([false, false]))
  end

  it "records the Ruby that bin/inventory read it from, so it changes only when someone regenerates it" do
    expect(described_class::SHIPPED.fetch("ruby")).to(match(/\A\d+\.\d+\.\d+\z/))
  end
end
