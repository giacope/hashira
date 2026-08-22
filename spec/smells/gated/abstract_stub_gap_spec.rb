# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::AbstractStubGap) do
  def unmet(files, yaml = Fixtures::BOTH_FACTS) = gated(files, yaml, "abstract_stub_gap")

  def zone(name, body, parent = nil) = Fixtures.zoned(name, body, parent)

  def base(body = "def call = raise(NotImplementedError)") = zone("Base", body)

  def pair(body, parent = "Base") = base.merge(zone("Heir", body, parent))

  it "names the class that never implements the stub" do
    expect(unmet(pair("def other = 1")).map(&:package)).to(eq(["App::Zone::Heir"]))
  end

  it "says which method was left unimplemented and who promised it" do
    expect(message(unmet(pair("def other = 1")).first)).to(
      include("never implements 'call', which App::Zone::Base leaves to it")
    )
  end

  it "quotes the stub it found" do
    expect(unmet(pair("def other = 1")).first.evidence).to(eq(["zone/base.rb:4"]))
  end

  it "says nothing once the subclass implements it" do
    expect(unmet(pair("def call = 1"))).to(be_empty)
  end

  it "says nothing when a class between them implements it" do
    files = pair("def other = 1", "Middle").merge(zone("Middle", "def call = 1", "Base"))
    expect(unmet(files)).to(be_empty)
  end

  it "says nothing about the class that owns the stub" do
    expect(unmet(base)).to(be_empty)
  end

  it "blames the leaf, not the class in the middle that also left it alone" do
    files = pair("def other = 1").merge(zone("Twig", "def more = 1", "Heir"))
    expect(unmet(files).map(&:package)).to(eq(["App::Zone::Twig"]))
  end

  it "reads a stub raised with a message" do
    files = base('def call = raise(NotImplementedError, "override me")').merge(zone("Heir", "def other = 1", "Base"))
    expect(unmet(files).map(&:package)).to(eq(["App::Zone::Heir"]))
  end

  it "reads a stub the class picks up from a module it includes" do
    mixin = Fixtures.zoned("Callable", "def call = raise(NotImplementedError)", nil, kind: :module)
    files = mixin.merge(zone("Heir", "include Callable\ndef other = 1"))
    expect(unmet(files).map(&:package)).to(eq(["App::Zone::Heir"]))
  end

  it "says nothing about a method that raises something else" do
    files = base("def call = raise(ArgumentError)").merge(zone("Heir", "def other = 1", "Base"))
    expect(unmet(files)).to(be_empty)
  end

  it "says nothing about a method that does more than raise" do
    files = base("def call\n  @seen = true\n  raise(NotImplementedError)\nend").merge(zone("Heir", "def x = 1", "Base"))
    expect(unmet(files)).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    files = zone("Heir", "def other = 1", "ActiveRecord::Base")
    expect(unmet(files)).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(unmet(pair("def other = 1"), nil)).to(be_empty)
  end

  it "says nothing when only one of the required facts is declared" do
    expect(unmet(pair("def other = 1"), Fixtures.facts(%w[no_method_missing], "lib/"))).to(be_empty)
  end
end
