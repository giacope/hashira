# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::UnchainedInitialize) do
  def stranded(files, yaml = Fixtures::THREE_FACTS) = gated(files, yaml, "unchained_initialize")

  def pair(parent, child)
    Fixtures.zoned("Base", parent).merge(Fixtures.zoned("Heir", child, "Base"))
  end

  def broken = pair("def initialize = @seed = 1", "def initialize = @own = 2")

  it "names the class that builds itself alone" do
    expect(stranded(broken).map(&:package)).to(eq(["App::Zone::Heir"]))
  end

  it "says which state stays nil and who assigns it" do
    expect(message(stranded(broken).first)).to(include("leaves '@seed' nil", "App::Zone::Base needs"))
  end

  it "quotes the constructor it skipped" do
    expect(stranded(broken).first.evidence).to(eq(["zone/base.rb:4"]))
  end

  it "says nothing once super is called" do
    expect(stranded(pair("def initialize = @seed = 1", "def initialize\n  super\n  @own = 2\nend"))).to(be_empty)
  end

  it "counts super with arguments" do
    files = pair("def initialize(one) = @seed = one", "def initialize(one)\n  super(one)\n  @own = 2\nend")
    expect(stranded(files)).to(be_empty)
  end

  it "says nothing when the parent constructor assigns nothing" do
    expect(stranded(pair("def initialize = nil", "def initialize = @own = 2"))).to(be_empty)
  end

  it "says nothing when the subclass has no constructor of its own" do
    expect(stranded(pair("def initialize = @seed = 1", "def call = 1"))).to(be_empty)
  end

  it "says nothing when nothing above defines a constructor" do
    expect(stranded(pair("def call = 1", "def initialize = @own = 2"))).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    expect(stranded(Fixtures.zoned("Heir", "def initialize = @own = 2", "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(stranded(broken, nil)).to(be_empty)
  end
end
