# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::DeadMethod) do
  def unused(files, yaml = Fixtures::THREE_FACTS) = gated(files, yaml, "dead_method")

  def zone(name, body, parent = nil) = Fixtures.zoned(name, body, parent)

  def thing(body) = zone("Thing", body)

  def orphan = thing("def run = 1\n\nprivate\n\ndef helper = 2")

  it "names the private method nothing calls" do
    expect(unused(orphan).map(&:package)).to(eq(["App::Zone::Thing#helper"]))
  end

  it "says which class was searched" do
    expect(message(unused(orphan).first)).to(
      include("is private, and nothing in App::Zone::Thing or below it ever names it")
    )
  end

  it "says nothing once something calls it" do
    expect(unused(thing("def run = helper\n\nprivate\n\ndef helper = 2"))).to(be_empty)
  end

  it "counts a call through self" do
    expect(unused(thing("def run = self.helper\n\nprivate\n\ndef helper = 2"))).to(be_empty)
  end

  it "counts a name a subclass calls" do
    files = thing("private\n\ndef helper = 2").merge(zone("Heir", "def run = helper", "Thing"))
    expect(unused(files)).to(be_empty)
  end

  it "counts a name spelled as a symbol, which send could reach" do
    expect(unused(thing("def run = __send__(:helper)\n\nprivate\n\ndef helper = 2"))).to(be_empty)
  end

  it "counts a name a block passes as a symbol" do
    expect(unused(thing("def run = [1].map(&:helper)\n\nprivate\n\ndef helper = 2"))).to(be_empty)
  end

  it "does not count the private marker that names it" do
    expect(unused(thing("def run = 1\n\ndef helper = 2\nprivate :helper")).map(&:package)).to(
      eq(["App::Zone::Thing#helper"])
    )
  end

  it "catches a protected method too" do
    expect(unused(thing("def run = 1\n\nprotected\n\ndef helper = 2")).first.detail[:section]).to(eq(:protected))
  end

  it "says nothing about a public method, which a caller outside may hold" do
    expect(unused(thing("def run = 1\n\ndef helper = 2"))).to(be_empty)
  end

  it "says nothing about initialize" do
    expect(unused(thing("def run = 1\n\nprivate\n\ndef initialize = @a = 1"))).to(be_empty)
  end

  it "says nothing about a module, whose private helpers travel to their hosts" do
    mixin = Fixtures.zoned("Helpers", "def run = 1\n\nprivate\n\ndef helper = 2", nil, kind: :module)
    expect(unused(mixin)).to(be_empty)
  end

  it "says nothing when the class dispatches by a name it computes" do
    body = "def run(key) = __send__(key)\n\nprivate\n\ndef helper = 2"
    expect(unused(thing(body))).to(be_empty)
  end

  it "says nothing when the class sends without naming anything at all" do
    expect(unused(thing("def run = __send__\n\nprivate\n\ndef helper = 2"))).to(be_empty)
  end

  it "says nothing when the class asks respond_to? about a name it computes" do
    body = "def run(key) = respond_to?(key)\n\nprivate\n\ndef helper = 2"
    expect(unused(thing(body))).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    expect(unused(zone("Thing", "private\n\ndef helper = 2", "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(unused(orphan, nil)).to(be_empty)
  end

  it "says nothing when no_eval is missing from the declarations" do
    expect(unused(orphan, Fixtures::BOTH_FACTS)).to(be_empty)
  end
end
