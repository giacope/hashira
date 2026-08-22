# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::OverrideArityMismatch) do
  def clashing(files, yaml = Fixtures::BOTH_FACTS) = gated(files, yaml, "override_arity_mismatch")

  def pair(parent, child)
    Fixtures.zoned("Base", parent).merge(Fixtures.zoned("Heir", child, "Base"))
  end

  def narrowed = pair("def call(one, two) = one", "def call(one) = one")

  it "names the override that cannot take the base's calls" do
    expect(clashing(narrowed).map(&:package)).to(eq(["App::Zone::Heir#call"]))
  end

  it "says whose calls it cannot take" do
    expect(message(clashing(narrowed).first)).to(include("cannot take the calls App::Zone::Base accepts"))
  end

  it "quotes what it refuses" do
    expect(clashing(narrowed).first.evidence).to(eq(["takes fewer arguments than App::Zone::Base#call"]))
  end

  it "catches an override that demands more than the base did" do
    expect(clashing(pair("def call(one = 1) = one", "def call(one) = one"))).not_to(be_empty)
  end

  it "catches an override that drops a keyword the base accepted" do
    findings = clashing(pair("def call(one:) = one", "def call(two: 2) = two"))
    expect(findings.first.evidence).to(include("rejects one: unlike App::Zone::Base#call"))
  end

  it "catches an override that demands a keyword the base did not" do
    findings = clashing(pair("def call(one: 1) = one", "def call(one:) = one"))
    expect(findings.first.evidence).to(include("demands one: unlike App::Zone::Base#call"))
  end

  it "says nothing when the signatures agree" do
    expect(clashing(pair("def call(one, two) = one", "def call(one, two) = two"))).to(be_empty)
  end

  it "says nothing when the override widens the base" do
    expect(clashing(pair("def call(one) = one", "def call(one, two = 2) = two"))).to(be_empty)
  end

  it "counts a splat as taking anything" do
    expect(clashing(pair("def call(one, two) = one", "def call(*rest) = rest"))).to(be_empty)
  end

  it "counts a double splat as accepting any keyword" do
    expect(clashing(pair("def call(one:) = one", "def call(**rest) = rest"))).to(be_empty)
  end

  it "says nothing about a forwarding override, which takes whatever it is handed" do
    expect(clashing(pair("def call(one, two) = one", "def call(...) = super"))).to(be_empty)
  end

  it "says nothing about initialize, which nobody calls through the base contract" do
    expect(clashing(pair("def initialize(one, two) = @a = one", "def initialize(one) = @a = one"))).to(be_empty)
  end

  it "says nothing about a method with no definition above it" do
    expect(clashing(pair("def other = 1", "def call(one) = one"))).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    expect(clashing(Fixtures.zoned("Heir", "def call(one) = one", "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(clashing(narrowed, nil)).to(be_empty)
  end
end
