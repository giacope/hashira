# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Audiences) do
  def audiences(usage) = described_class.new(usage.transform_values(&:to_set))
  it "splits disjoint client bases into separate audiences" do
    split = audiences("a" => %w[X Y], "b" => %w[X Y], "c" => %w[P Q], "d" => %w[P Q])
    expect(split).to(be_split)
    expect(split.parts.map(&:users)).to(eq([%w[a b], %w[c d]]))
    expect(split.parts.map(&:constants)).to(eq([%w[X Y], %w[P Q]]))
    expect(split.parts.map(&:shared)).to(eq([false, false]))
  end

  it "separates a majority-shared kernel from a single client's private slice" do
    split = audiences(
      "root" => %w[Graph Census], "complexity" => %w[Finding Walk],
      "duplication" => %w[Finding Walk Syntax], "smells" => %w[Finding Walk Types]
    )
    expect(split).to(be_split)
    kernel, slice = split.parts
    expect(kernel.to_h).to(eq(users: %w[complexity duplication smells], constants: %w[Finding Walk], shared: true))
    expect(slice.to_h).to(eq(users: %w[root], constants: %w[Census Graph], shared: false))
  end

  it "keeps a package whole when client slices overlap" do
    expect(audiences("a" => %w[X Y], "b" => %w[Y Z])).not_to(be_split)
  end

  it "keeps a package whole when every client uses the same constants" do
    expect(audiences("a" => %w[X Y Z], "b" => %w[X Y Z], "c" => %w[X Y Z])).not_to(be_split)
  end

  it "ignores seams narrower than two constants per side" do
    expect(audiences("a" => %w[X], "b" => %w[Y])).not_to(be_split)
  end

  it "stays quiet without clients" do
    expect(audiences({})).not_to(be_split)
  end
end
