# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::RescueShadow) do
  def shadowed(files, yaml = Fixtures::ALL_FACTS) = gated(files, yaml, "rescue_shadow")

  def errors = Fixtures.zoned("Snag", "def note = 1", "StandardError")

  def guard(body) = errors.merge(Fixtures.zoned("Thing", body))

  def buried = guard("def run\n  work\nrescue StandardError\n  1\nrescue Snag\n  2\nend")

  it "names the method whose later clause never runs" do
    expect(shadowed(buried).map(&:package)).to(eq(["App::Zone::Thing#run"]))
  end

  it "says which clause already caught it" do
    expect(message(shadowed(buried).first)).to(include("rescues 'Snag' after StandardError, which already catches it"))
  end

  it "quotes the clause that swallows it" do
    expect(shadowed(buried).first.evidence).to(eq(["zone/thing.rb:6: rescue StandardError"]))
  end

  it "catches the same class rescued twice" do
    expect(shadowed(guard("def run\n  work\nrescue Snag\n  1\nrescue Snag\n  2\nend")).size).to(eq(1))
  end

  it "follows a project hierarchy two deep" do
    files = errors.merge(Fixtures.zoned("Worse", "def note = 2", "Snag"))
    deep = Fixtures.zoned("Thing", "def run\n  work\nrescue Snag\n  1\nrescue Worse\n  2\nend")
    expect(shadowed(files.merge(deep)).size).to(eq(1))
  end

  it "says nothing when the narrower clause comes first" do
    expect(shadowed(guard("def run\n  work\nrescue Snag\n  1\nrescue StandardError\n  2\nend"))).to(be_empty)
  end

  it "says nothing about two unrelated classes" do
    expect(shadowed(guard("def run\n  work\nrescue ArgumentError\n  1\nrescue TypeError\n  2\nend"))).to(be_empty)
  end

  it "says nothing about one clause listing several classes" do
    expect(shadowed(guard("def run\n  work\nrescue ArgumentError, TypeError\n  1\nend"))).to(be_empty)
  end

  it "says nothing about a clause whose class is computed" do
    expect(shadowed(guard("def run(kind)\n  work\nrescue StandardError\n  1\nrescue kind\n  2\nend"))).to(be_empty)
  end

  it "says nothing about a bare rescue, which names nothing hashira can compare" do
    expect(shadowed(guard("def run\n  work\nrescue\n  1\nend"))).to(be_empty)
  end

  it "says nothing about clauses in different begins" do
    body = "def run\n  begin\n    work\n  rescue StandardError\n    1\n  end\n  more\nrescue Snag\n  2\nend"
    expect(shadowed(guard(body))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(shadowed(buried, nil)).to(be_empty)
  end
end
