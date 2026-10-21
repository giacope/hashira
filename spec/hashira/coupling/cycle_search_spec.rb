# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::CycleSearch) do
  it "walks back the shortest way to the package, keeping the first way it reached each step" do
    dependencies = { a: %i[b c], b: %i[c], c: %i[a] }
    expect([described_class.new(dependencies, :a).path, described_class.new({ a: %i[b], b: [] }, :a).path])
      .to(eq([%i[a c a], nil]))
  end
end
