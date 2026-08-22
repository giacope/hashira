# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::UnansweredMessage) do
  def astray(files, yaml = Fixtures::ALL_FACTS) = gated(files, yaml, "unanswered_message")

  def thing(body) = Fixtures.zoned("Thing", body)

  def typo = thing("def run = helpr\n\nprivate\n\ndef helper = 1")

  it "names the method that calls something nothing defines" do
    expect(astray(typo).map(&:package)).to(eq(["App::Zone::Thing#run"]))
  end

  it "says which name went unanswered" do
    expect(message(astray(typo).first)).to(
      include("calls 'helpr' on itself, and nothing App::Zone::Thing can reach defines it")
    )
  end

  it "points at the line that calls it" do
    expect(astray(typo).first.evidence).to(eq(["zone/thing.rb:4"]))
  end

  it "says nothing once the name is spelled right" do
    expect(astray(thing("def run = helper\n\nprivate\n\ndef helper = 1"))).to(be_empty)
  end

  it "counts a method an ancestor defines" do
    base = Fixtures.zoned("Base", "def helper = 1")
    expect(astray(base.merge(Fixtures.zoned("Heir", "def run = helper", "Base")))).to(be_empty)
  end

  it "counts a reader attr_reader grants" do
    expect(astray(thing("attr_reader :seed\n\ndef run = seed"))).to(be_empty)
  end

  it "counts what Ruby itself answers" do
    expect(astray(thing("def run = format(\"%s\", freeze)"))).to(be_empty)
  end

  it "counts a call through self" do
    expect(astray(thing("def run = self.helper\n\nprivate\n\ndef helper = 1"))).to(be_empty)
  end

  it "says nothing about a call with a receiver" do
    expect(astray(thing("def run(other) = other.helpr"))).to(be_empty)
  end

  it "says nothing about a block argument being passed along" do
    expect(astray(thing("def run(&block) = [1].each(&block)"))).to(be_empty)
  end

  it "says nothing about a module, whose host may answer for it" do
    expect(astray(Fixtures.zoned("Helpers", "def run = helpr", nil, kind: :module))).to(be_empty)
  end

  it "says nothing when the class body runs a macro hashira does not know" do
    expect(astray(thing("delegate :helper, to: :seed\n\ndef run = helpr"))).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    expect(astray(Fixtures.zoned("Thing", "def run = helpr", "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(astray(typo, nil)).to(be_empty)
  end

  it "says nothing when no_refinements is missing from the declarations" do
    expect(astray(typo, Fixtures::THREE_FACTS)).to(be_empty)
  end
end
