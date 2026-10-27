# frozen_string_literal: true

RSpec.describe(Hashira::Config::Rules, :aggregate_failures) do
  def parse(raw)
    described_class.parse(raw, %w[complexity dead_code feature_envy fragmentation nil_check state_sprawl])
  end

  it "turns kinds off and moves thresholds" do
    rules = parse("feature_envy" => false, "complexity" => { "threshold" => 4 }, "state_sprawl" => true)
    expect([rules.enabled?("feature_envy"), rules.enabled?("complexity")]).to(eq([false, true]))
    expect([rules.threshold("complexity", 10), rules.threshold("state_sprawl", 4)]).to(eq([4, 4]))
    expect(parse("complexity" => { "enabled" => false }).enabled?("complexity")).to(be(false))
  end

  it "leaves measured kinds on and low-precision kinds off when nothing is said, and all of them on for all" do
    defaults = Hashira::Config::Rules::NONE
    expect(%w[complexity duplication nil_check indirection dead_code change_coupling].map { defaults.enabled?(it) })
      .to(eq([true, true, true, false, true, false]))
    expect(defaults.threshold("complexity", 10)).to(eq(10))
    expect([parse("all"), parse("nil_check" => true), defaults.naming(%w[nil_check])].map { it.enabled?("nil_check") })
      .to(eq([true, true, true]))
    expect(parse("all").enabled?("indirection")).to(be(true))
  end

  it "holds the strict kinds back, under all too, and tightening turns on exactly them, carried through every copy" do
    plain = [Hashira::Config::Rules::NONE, Hashira::Config::Rules::ALL, parse("all" => true), parse({})]
    moved = plain.map { |rules| Hashira::Pipeline::KINDS.reject { rules.enabled?(it) == rules.tightened.enabled?(it) } }
    copies = plain.first.tightened.naming(["nil_check"]).layered(Hashira::Config::Layers::NONE).bounded([])
    strict = plain.map(&:strict?) + [copies.strict?, copies.narrowed(["nil_check"], ["nil_check"]).strict?]
    expect([moved, strict]).to(eq([[Hashira::Config::Rules::STRICT] * 4, ([false] * 4) + [true, true]]))
  end

  it "turns a strict kind on when checks: names it, but not when a flag names it" do
    named = described_class.parse({ "stateful_mixin" => true }, Hashira::Pipeline::KINDS)
    flagged = Hashira::Config::Rules::ALL.naming(["stateful_mixin"])
    expect([named, flagged].map { [it.enabled?("stateful_mixin"), it.strict?] }).to(eq([[true, false], [false, false]]))
  end

  it "moves a kind's named limits, and keeps the default for one not given" do
    rules = parse("fragmentation" => { "helpers" => 6, "lines" => 2.5 })
    limits = %w[helpers lines].map { rules.limit("fragmentation", it, 1) }
    expect(limits + [parse({}).limit("x", "y", 7)]).to(eq([6, 2.5, 7]))
  end

  it "turns every kind on with all: true, beside settings that still move or drop one" do
    rules = parse("all" => true, "nil_check" => false, "complexity" => { "threshold" => 4 })
    switches = %w[feature_envy nil_check dead_code].map { rules.enabled?(it) }
    switches += [parse("all" => false), parse("complexity" => true)].map { it.enabled?("indirection") }
    expect(switches + [rules.threshold("complexity", 10)]).to(eq([true, false, true, false, false, 4]))
  end

  it "reads a kind's named lists, and carries declared layers through naming" do
    rules = parse("dead_code" => { "roots" => ["App::Cli", "lib/app/cli"] })
    layers = Hashira::Config::Layers.parse(%w[web domain])
    named = rules.layered(layers).naming(["dead_code"])
    expect([rules.limit("dead_code", "roots", []), named.layers.names, named.enabled?("dead_code")]).to(
      eq([["App::Cli", "lib/app/cli"], %w[web domain], true])
    )
  end

  it "narrows to the kinds asked for, keeping their settings, and changes nothing when none is asked for" do
    rules = parse({ "complexity" => { "threshold" => 9 }, "nil_check" => false })
    every = %w[complexity dead_code nil_check]
    narrowed = rules.narrowed(%w[complexity nil_check], every)
    expect([rules.narrowed([], every), every.map { narrowed.enabled?(it) }, narrowed.threshold("complexity", 15)])
      .to(eq([rules, [true, false, false], 9]))
  end

  it "refuses what it cannot apply" do
    {
      ["complexity"] => "checks takes all, or kind: settings",
      { "envy" => false } => 'unknown kind "envy"',
      { "complexity" => "off" } => "complexity takes true, false or { threshold: N }",
      { "complexity" => { "limit" => 3 } } => 'complexity has no setting "limit"',
      { "feature_envy" => { "threshold" => 3 } } => "no threshold (thresholds: boundary_sprawl, complexity,",
      { "complexity" => { "threshold" => 0 } } => "threshold must be a positive whole number",
      { "complexity" => { "threshold" => "3" } } => "threshold must be a positive whole number",
      { "fragmentation" => { "lines" => 0 } } => "fragmentation lines must be a positive number",
      { "fragmentation" => { "helpers" => "4" } } => "fragmentation helpers must be a positive number",
      { "complexity" => { "helpers" => 4 } } => 'complexity has no setting "helpers" (use: enabled, threshold)',
      { "all" => "yes" } => 'checks: all takes true or false, not "yes"',
      { "dead_code" => { "roots" => [3] } } => "dead_code roots takes a list of names",
      { "dead_code" => { "roots" => [""] } } => "dead_code roots takes a list of names"
    }.each { |raw, message| expect { parse(raw) }.to(raise_error(Hashira::Error, /#{Regexp.escape(message)}/)) }
  end

  it "turns the opt-in and history kinds on with all: true, and keeps off a kind the same hash turns off" do
    rules = parse("all" => true, "feature_envy" => false)
    expect(%w[indirection change_coupling feature_envy].map { rules.enabled?(it) }).to(eq([true, true, false]))
  end
end
