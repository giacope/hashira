# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::RegistryGap) do
  def gap(files, yaml = Fixtures::BOTH_FACTS, directories: ["lib/app"])
    gated(files, yaml, "registry_gap", directories:)
  end

  def zone(name, body, parent = nil)
    { "lib/app/zone/#{name.downcase}.rb" => Fixtures.wrapped("App::Zone::#{name}", body, parent) }
  end

  def dispatcher(body) = zone("Thing", body)

  def table = "TABLE = { a: :on_a, b: :on_b }.freeze"

  def routed = "def run(key) = __send__(TABLE.fetch(key))"

  def holed = "#{table}\n#{routed}\ndef on_a = 1"

  def whole = "#{holed}\ndef on_b = 2"

  def facts(scope) = Fixtures.facts(%w[no_method_missing no_define_method], scope)

  it "names the registry the hole belongs to" do
    expect(gap(dispatcher(holed)).map(&:package)).to(eq(["App::Zone::Thing::TABLE"]))
  end

  it "says which handler the class cannot answer" do
    expect(message(gap(dispatcher(holed)).first)).to(
      include("routes to 'on_b', which App::Zone::Thing cannot answer")
    )
  end

  it "quotes the key whose handler is missing" do
    expect(gap(dispatcher(holed)).first.evidence).to(eq(["b: → #on_b"]))
  end

  it "names the file the registry lives in, so --only can narrow to it" do
    expect(gap(dispatcher(holed)).first.sources).to(eq(["zone/thing.rb"]))
  end

  it "says nothing once the handler exists" do
    expect(gap(dispatcher(whole))).to(be_empty)
  end

  it "counts a handler a private section defines" do
    expect(gap(dispatcher("#{whole}\nprivate :on_b"))).to(be_empty)
  end

  it "counts a handler an ancestor defines" do
    expect(gap(zone("Base", "def on_b = 2").merge(zone("Thing", holed, "Base")))).to(be_empty)
  end

  it "counts a handler a subclass defines, because the base dispatches for them" do
    expect(gap(dispatcher(holed).merge(zone("Heir", "def on_b = 2", "Thing")))).to(be_empty)
  end

  it "counts a reader attr_reader grants" do
    expect(gap(dispatcher("#{table}\n#{routed}\nattr_reader :on_a, :on_b"))).to(be_empty)
  end

  it "counts the fallback fetch names, not only the entries" do
    body = "TABLE = { a: :on_a }.freeze\ndef run(key) = __send__(TABLE.fetch(key, :plain))\ndef on_a = 1"
    expect(gap(dispatcher(body)).first.evidence).to(eq(["(missing key) → #plain"]))
  end

  it "reads a merge chain as one table" do
    body = "TABLE = { a: :on_a }.merge(b: :on_b).freeze\n#{routed}\ndef on_a = 1"
    expect(gap(dispatcher(body)).first.detail[:names]).to(eq([:on_b]))
  end

  it "says nothing about a table that is never dispatched" do
    expect(gap(dispatcher("#{table}\ndef keys = TABLE.keys"))).to(be_empty)
  end

  it "says nothing about a table that is not frozen, because anything may still be added" do
    expect(gap(dispatcher("TABLE = { a: :on_a, b: :on_b }\n#{routed}"))).to(be_empty)
  end

  it "says nothing about a table built from something other than literals" do
    expect(gap(dispatcher("TABLE = OTHER.merge(b: :on_b).freeze\n#{routed}"))).to(be_empty)
  end

  it "says nothing when the values are not handler names" do
    expect(gap(dispatcher("TABLE = { a: \"one\", b: \"two\" }.freeze\n#{routed}"))).to(be_empty)
  end

  it "says nothing when the send goes to another object" do
    body = "TABLE = { a: :on_a }.freeze\ndef run(other, key) = other.__send__(TABLE.fetch(key))"
    expect(gap(dispatcher(body))).to(be_empty)
  end

  it "says nothing when the send carries no argument at all" do
    expect(gap(dispatcher("TABLE = { a: :on_a }.freeze\ndef run = __send__"))).to(be_empty)
  end

  it "says nothing when the send names its method outright instead of reading the table" do
    body = "TABLE = { a: :on_a }.freeze\ndef run = __send__(:plain)\ndef plain = 1"
    expect(gap(dispatcher(body))).to(be_empty)
  end

  it "still reads a table whose fetch was written without a key" do
    body = "TABLE = { a: :on_a }.freeze\ndef run = __send__(TABLE.fetch)"
    expect(gap(dispatcher(body)).first.detail[:names]).to(eq([:on_a]))
  end

  it "says nothing when the class inherits something the project cannot see" do
    expect(gap(zone("Thing", holed, "ActiveRecord::Base"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints at all" do
    expect(gap(dispatcher(holed), nil)).to(be_empty)
  end

  it "says nothing when only one of the required facts is declared" do
    expect(gap(dispatcher(holed), Fixtures.facts(%w[no_method_missing], "lib/"))).to(be_empty)
  end

  it "says nothing when the declared scope does not reach the analyzed files" do
    files = dispatcher(holed).merge("other/keep.rb" => "class Keep; def a = 1; end\n")
    expect(gap(files, facts("other/"))).to(be_empty)
  end

  it "says nothing when the scope covers only part of what this run parses" do
    files = dispatcher(holed).merge("lib/edge/side.rb" => "class Side; def a = 1; end\n")
    expect(gap(files, facts("lib/app"), directories: ["lib/app", "lib/edge"])).to(be_empty)
  end

  it "speaks up again once the scope covers every file the run parses" do
    files = dispatcher(holed).merge("lib/edge/side.rb" => "class Side; def a = 1; end\n")
    expect(gap(files, facts("lib/"), directories: ["lib/app", "lib/edge"]).size).to(eq(1))
  end

  it "refuses the run when method_missing contradicts the declaration" do
    expect { gap(dispatcher("#{holed}\ndef method_missing(name, *) = super")) }.to(
      raise_error(Hashira::Error, %r{no_method_missing is contradicted by lib/app/zone/thing\.rb:7})
    )
  end

  it "refuses the run when define_method contradicts the declaration" do
    expect { gap(dispatcher("#{holed}\ndefine_method(:on_b) { 2 }")) }.to(
      raise_error(Hashira::Error, %r{no_define_method is contradicted by lib/app/zone/thing\.rb:7})
    )
  end

  it "ignores a contradiction outside the declared scope" do
    loose = "class Loose\n  def method_missing(name, *) = super\nend\n"
    expect(gap(dispatcher(whole).merge("other/loose.rb" => loose))).to(be_empty)
  end

  it "reports the same finding whichever order the files are read in" do
    expect(gap(dispatcher(holed).merge(zone("Aaa", "def a = 1"))).map(&:package)).to(eq(["App::Zone::Thing::TABLE"]))
  end
end
