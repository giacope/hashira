# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Ownership, :aggregate_failures) do
  let(:everything) { Class.new { def claimed?(_full) = true }.new }

  let(:ownership) do
    tree = Prism.parse("module App\n  class Store\n  end\nend\n").value
    described_class.new(Hashira::Smells::Walk.new([tree]), everything)
  end

  it "anchors a constant to the owned class it names from inside a namespace, and keeps one it does not own" do
    anchored = [[%w[Store], "App"], [%w[Cache], "App"], [[], "App::Store"]].map { ownership.anchored(*it) }
    expect(anchored).to(eq([%w[App Store], %w[Cache], []]))
  end
end
