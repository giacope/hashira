# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Builtin) do
  it "knows constants Ruby defines without a Ruby source file" do
    expect(%w[Process Comparable].map { described_class.native?(it) }).to(eq([true, true]))
  end

  it "does not count a constant defined in a gem or project file, or not defined at all, as native" do
    expect(%w[Hashira NoSuchConstantAnywhere].map { described_class.native?(it) }).to(eq([false, false]))
  end

  it "finds a standard library on Ruby's own shelves without loading it" do
    expect(%w[logger net zlib rack].map { described_class.shelved?(it) }).to(eq([true, true, true, false]))
  end

  it "counts a gem Ruby ships bundled as standard library, wherever it is installed" do
    expect(%w[logger csv rack].map { described_class.shelved?(it) }).to(eq([true, true, false]))
  end

  it "counts core and standard-library names, loaded or not, and nothing else" do
    names = %w[Process Set JSON Logger URI Date Net Hashira Rack Billing]
    expect(names.select { described_class.include?(it) }).to(eq(%w[Process Set JSON Logger URI Date Net]))
  end
end
