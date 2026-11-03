# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Tree, :aggregate_failures) do
  let(:tree) { described_class.new("C" => %w[B], "B" => %w[A], "A" => [], "X" => %w[Y], "Y" => %w[X]) }

  it "walks a name's ancestors up to its root, and stops where a cycle comes back" do
    expect([tree.ancestors("C"), tree.ancestors("X"), tree.ancestors("Z")]).to(eq([%w[B A], %w[Y], []]))
  end

  it "lists a name's children and descendants, and answers no parent for a root or a name it does not hold" do
    found = [tree.children("A"), tree.descendants("A"), tree.descendants("X"), tree.parent("A"), tree.parent("Z")]
    expect(found).to(eq([%w[B], %w[B C], %w[Y], [], []]))
  end
end
