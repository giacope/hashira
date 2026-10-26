# frozen_string_literal: true

RSpec.describe(Hashira::Analysis, :aggregate_failures) do
  it "counts a gem Ruby ships bundled as standard library, wherever it is installed" do
    expect(%w[csv bigdecimal rack].map { described_class::LIBRARIES.include?(it) }).to(eq([true, true, false]))
  end

  it "reads what a bare Ruby ships, not what this process happens to have loaded" do
    loaded = [described_class::CORE.include?("RSpec"), described_class::UNIVERSAL.include?(:to_json)]
    expect(loaded).to(eq([false, false]))
  end

  it "knows what each core class answers beyond Object, through its own ancestors" do
    inherited = described_class::INHERITED
    expect([inherited.fetch("StandardError").include?(:message), inherited.fetch("Hash").include?(:fetch)])
      .to(eq([true, true]))
    expect(inherited.fetch("StandardError")).not_to(include(:puts, :fetch))
  end

  it "records the Ruby that bin/inventory read it from, so it changes only when someone regenerates it" do
    expect(described_class::SHIPPED.fetch("ruby")).to(match(/\A\d+\.\d+\.\d+\z/))
  end
end
