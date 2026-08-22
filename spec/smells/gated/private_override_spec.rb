# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::PrivateOverride) do
  def narrowed(files, yaml = Fixtures::BOTH_FACTS) = gated(files, yaml, "private_override")

  def base(body = "def call = 1") = Fixtures.zoned("Base", body)

  def pair(body) = base.merge(Fixtures.zoned("Heir", body, "Base"))

  def sealed = pair("private\ndef call = 2")

  it "names the override that hides what the base offered" do
    expect(narrowed(sealed).map(&:package)).to(eq(["App::Zone::Heir#call"]))
  end

  it "says who made it public and what breaks" do
    expect(message(narrowed(sealed).first)).to(
      include("is private here, but App::Zone::Base makes it public", "NoMethodError")
    )
  end

  it "quotes the public definition it is narrowing" do
    expect(narrowed(sealed).first.evidence).to(eq(["zone/base.rb:4"]))
  end

  it "catches a protected override too" do
    expect(narrowed(pair("protected\ndef call = 2")).first.detail[:section]).to(eq(:protected))
  end

  it "catches a private marked after the fact" do
    expect(narrowed(pair("def call = 2\nprivate :call")).map(&:package)).to(eq(["App::Zone::Heir#call"]))
  end

  it "says nothing when the override stays public" do
    expect(narrowed(pair("def call = 2"))).to(be_empty)
  end

  it "says nothing when the base kept it private too" do
    files = base("private\ndef call = 1").merge(Fixtures.zoned("Heir", "private\ndef call = 2", "Base"))
    expect(narrowed(files)).to(be_empty)
  end

  it "says nothing about a private method the base never had" do
    expect(narrowed(pair("private\ndef other = 2"))).to(be_empty)
  end

  it "says nothing about initialize, which Ruby keeps private anyway" do
    files = base("def initialize = @a = 1").merge(Fixtures.zoned("Heir", "private\ndef initialize = @a = 2", "Base"))
    expect(narrowed(files)).to(be_empty)
  end

  it "says nothing when the ancestry leaves the project" do
    expect(narrowed(Fixtures.zoned("Heir", "private\ndef call = 2", "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(narrowed(sealed, nil)).to(be_empty)
  end
end
