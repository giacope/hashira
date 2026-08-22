# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::UnreachableRescue) do
  def dead(files, yaml = Fixtures::ALL_FACTS) = gated(files, yaml, "unreachable_rescue")

  def error(name = "Snag", parent = "StandardError") = Fixtures.zoned(name, "def note = 1", parent)

  def guard(body) = error.merge(Fixtures.zoned("Thing", body))

  def caught = guard("def run\n  work\nrescue Snag\n  nil\nend")

  it "names the method whose rescue nothing can trigger" do
    expect(dead(caught).map(&:package)).to(eq(["App::Zone::Thing#run"]))
  end

  it "says which class it rescues in vain" do
    expect(message(dead(caught).first)).to(include("rescues 'App::Zone::Snag', which nothing in the project raises"))
  end

  it "says nothing once something raises it" do
    expect(dead(guard("def run\n  raise(Snag)\nrescue Snag\n  nil\nend"))).to(be_empty)
  end

  it "counts a raise of a subclass" do
    files = caught.merge(Fixtures.zoned("Worse", "def note = 2", "Snag"))
    expect(dead(files.merge(Fixtures.zoned("Maker", "def go = raise(Worse)")))).to(be_empty)
  end

  it "counts a raise built with new" do
    expect(dead(guard("def run\n  raise(Snag.new)\nrescue Snag\n  nil\nend"))).to(be_empty)
  end

  it "says nothing about an error the project does not define" do
    expect(dead(guard("def run\n  work\nrescue ArgumentError\n  nil\nend"))).to(be_empty)
  end

  it "says nothing anywhere once the project raises something it cannot read" do
    loose = Fixtures.zoned("Maker", "def go(kind) = raise(kind)")
    expect(dead(caught.merge(loose))).to(be_empty)
  end

  it "reads a raise with only a message as raising nothing named" do
    loose = Fixtures.zoned("Maker", 'def go = raise("boom")')
    expect(dead(caught.merge(loose)).map(&:package)).to(eq(["App::Zone::Thing#run"]))
  end

  it "reads a bare re-raise as raising nothing new" do
    loose = Fixtures.zoned("Maker", "def go\n  work\nrescue ArgumentError\n  raise\nend")
    expect(dead(caught.merge(loose)).map(&:package)).to(eq(["App::Zone::Thing#run"]))
  end

  it "says nothing when the project declares no constraints" do
    expect(dead(caught, nil)).to(be_empty)
  end
end
