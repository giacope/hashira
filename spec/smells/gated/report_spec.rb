# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::Report) do
  def holed = "TABLE = { a: :on_a, b: :on_b }.freeze\ndef run(key) = __send__(TABLE.fetch(key))\ndef on_a = 1"

  def thing = Fixtures.zoned("Thing", holed)

  def edge = { "lib/edge/side.rb" => "class Side; def a = 1; end\n" }

  def kinds(files, yaml, directories: ["lib/app"])
    constrained(files, yaml, directories:) { |pipeline| return pipeline.findings.map(&:kind).uniq }
  end

  it "names every rule it knows, so --fail-on and the baseline can too" do
    expect(described_class::KINDS).to(eq(described_class::KINDS.sort.uniq))
  end

  it "counts one kind per rule" do
    expect(described_class::KINDS.size).to(eq(described_class::RULES.size))
  end

  it "lists every gated kind among the smells --fail-on covers" do
    expect(Hashira::Plan::SMELLS).to(include(*described_class::KINDS))
  end

  it "runs a rule when the declarations cover every file the run parses" do
    expect(kinds(thing, Fixtures::ALL_FACTS)).to(include("registry_gap"))
  end

  it "stays silent when the project declares nothing" do
    expect(kinds(thing, nil)).not_to(include("registry_gap"))
  end

  it "stays silent when the scope reaches none of the analyzed files" do
    files = thing.merge("other/keep.rb" => "class Keep; def a = 1; end\n")
    yaml = Fixtures.facts(%w[no_method_missing no_define_method], "other/")
    expect(kinds(files, yaml)).not_to(include("registry_gap"))
  end

  it "stays silent when the scope covers only part of what this run parses" do
    yaml = Fixtures.facts(%w[no_method_missing no_define_method], "lib/app")
    expect(kinds(thing.merge(edge), yaml, directories: ["lib/app", "lib/edge"])).not_to(include("registry_gap"))
  end

  it "speaks again once the scope widens to the whole run" do
    yaml = Fixtures.facts(%w[no_method_missing no_define_method], "lib/")
    expect(kinds(thing.merge(edge), yaml, directories: ["lib/app", "lib/edge"])).to(include("registry_gap"))
  end

  it "refuses the run outright when a declaration is contradicted" do
    hook = Fixtures.zoned("Loose", "def method_missing(name, *) = super")
    expect { kinds(thing.merge(hook), Fixtures::ALL_FACTS) }.to(
      raise_error(Hashira::Error, /constraint no_method_missing is contradicted by/)
    )
  end

  it "leaves an unconstrained project exactly the findings it had before" do
    plain = Fixtures.zoned("Thing", "def run(word) = word.to_s")
    expect(kinds(plain, nil)).to(eq(kinds(plain, Fixtures::ALL_FACTS)))
  end
end
