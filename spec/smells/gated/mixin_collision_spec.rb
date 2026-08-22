# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::MixinCollision) do
  def clashing(files, yaml = Fixtures::THREE_FACTS) = gated(files, yaml, "mixin_collision")

  def mixin(name, body) = Fixtures.zoned(name, body, nil, kind: :module)

  def sides = mixin("Alpha", "def call = 1").merge(mixin("Beta", "def call = 2"))

  def both(body) = sides.merge(Fixtures.zoned("Thing", body))

  def contested = both("include Alpha\ninclude Beta")

  it "names the class the two modules land in" do
    expect(clashing(contested).map(&:package)).to(eq(["App::Zone::Thing"]))
  end

  it "says who defined the same method and what happens" do
    expect(message(clashing(contested).first)).to(
      include("each define 'call' into App::Zone::Thing", "the last include silently wins")
    )
  end

  it "quotes both definitions" do
    expect(clashing(contested).first.evidence).to(eq(["zone/alpha.rb:4", "zone/beta.rb:4"]))
  end

  it "says nothing when the class settles it itself" do
    expect(clashing(both("include Alpha\ninclude Beta\ndef call = 3"))).to(be_empty)
  end

  it "says nothing when only one module defines the name" do
    files = mixin("Alpha", "def call = 1").merge(mixin("Beta", "def other = 2"))
    expect(clashing(files.merge(Fixtures.zoned("Thing", "include Alpha\ninclude Beta")))).to(be_empty)
  end

  it "says nothing when only one module is included" do
    expect(clashing(both("include Alpha"))).to(be_empty)
  end

  it "says nothing about a superclass and a module sharing a name, which Ruby orders" do
    files = mixin("Alpha", "def call = 1").merge(Fixtures.zoned("Base", "def call = 2"))
    expect(clashing(files.merge(Fixtures.zoned("Thing", "include Alpha", "Base")))).to(be_empty)
  end

  it "says nothing when a module is not one the project defines" do
    expect(clashing(Fixtures.zoned("Thing", "include Comparable\ninclude Enumerable"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(clashing(contested, nil)).to(be_empty)
  end
end
