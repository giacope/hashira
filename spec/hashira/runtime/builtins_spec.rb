# frozen_string_literal: true

RSpec.describe(Hashira::Runtime::Builtins, :aggregate_failures) do
  it "counts a gem Ruby ships bundled as standard library, wherever it is installed" do
    expect(%w[csv bigdecimal rack].map { described_class.new.library?(it) }).to(eq([true, true, false]))
  end

  it "reads what a bare Ruby ships, not what this process happens to have loaded" do
    loaded = [described_class.new.core?("RSpec"), Hashira::Runtime::Messages.new.universal?(:to_json)]
    expect(loaded).to(eq([false, false]))
  end

  it "knows what each core class answers beyond Object, through its own ancestors" do
    builtins = described_class.new
    expect([builtins.heritage("StandardError").include?(:message), builtins.heritage("Hash").include?(:fetch)])
      .to(eq([true, true]))
    expect(builtins.heritage("StandardError")).not_to(include(:puts, :fetch))
  end

  it "records the Ruby that bin/inventory read it from, so it changes only when someone regenerates it" do
    shipped = YAML.load_file(File.expand_path("../../../lib/hashira/runtime/inventory.yml", __dir__))
    expect(shipped.fetch("ruby")).to(match(/\A\d+\.\d+\.\d+\z/))
  end
end
