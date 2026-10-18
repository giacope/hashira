# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::RollCall) do
  def rolls(lists, homes)
    described_class.new(lists.transform_values { |list| literals(list) }, homes).rolls
  end

  def literals(list) = list.first.is_a?(Array) ? list.map { Set.new(it) } : [Set.new(list)]

  it "finds the words that travel together across packages" do
    found = rolls(
      { "a.rb" => %w[w x y], "b.rb" => %w[w x y z], "c.rb" => %w[w x y] },
      { "a.rb" => "p", "b.rb" => "q", "c.rb" => "p" }
    )
    expect(found.map(&:to_h)).to(eq([{ words: %w[w x y], files: %w[a.rb b.rb c.rb], packages: %w[p q] }]))
  end

  it "keeps only the widest roll when one swallows another" do
    found = rolls(
      { "a.rb" => %w[w x y z], "b.rb" => %w[w x y z], "c.rb" => %w[w x y z], "d.rb" => %w[x y z] },
      { "a.rb" => "p", "b.rb" => "q", "c.rb" => "r", "d.rb" => "s" }
    )
    expect(found.map(&:words)).to(eq([%w[w x y z]]))
  end

  it "ignores words that never leave one package" do
    found = rolls(
      { "a.rb" => %w[x y z], "b.rb" => %w[x y z], "c.rb" => %w[x y z] },
      { "a.rb" => "p", "b.rb" => "p", "c.rb" => "p" }
    )
    expect(found).to(be_empty)
  end

  it "ignores lists shared by fewer than three files" do
    expect(rolls({ "a.rb" => %w[x y z], "b.rb" => %w[x y z] }, { "a.rb" => "p", "b.rb" => "q" })).to(be_empty)
  end

  it "ignores coincidental pairs of words" do
    lists = { "a.rb" => %w[x y], "b.rb" => %w[x y], "c.rb" => %w[x y] }
    expect(rolls(lists, { "a.rb" => "p", "b.rb" => "q", "c.rb" => "r" })).to(be_empty)
  end

  it "reads each literal on its own, so words split across a file's lists are not one roll" do
    lists = {
      "a.rb" => [%w[show], %w[create update]],
      "b.rb" => [%w[create], %w[update show]],
      "c.rb" => [%w[show update], %w[create]]
    }
    expect(rolls(lists, { "a.rb" => "p", "b.rb" => "q", "c.rb" => "r" })).to(be_empty)
  end

  it "finds a roll that one literal in each file holds whole" do
    lists = { "a.rb" => [%w[x y z], %w[q]], "b.rb" => [%w[q], %w[w x y z]], "c.rb" => [%w[z y x]] }
    found = rolls(lists, { "a.rb" => "p", "b.rb" => "q", "c.rb" => "r" })
    expect(found.map(&:to_h)).to(eq([{ words: %w[x y z], files: %w[a.rb b.rb c.rb], packages: %w[p q r] }]))
  end
end
