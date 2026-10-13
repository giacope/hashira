# frozen_string_literal: true

RSpec.describe(Hashira::Config::Rules) do
  def parse(raw) = described_class.parse(raw, %w[complexity feature_envy nil_check state_sprawl])

  it "turns kinds off and moves thresholds" do
    rules = parse("feature_envy" => false, "complexity" => { "threshold" => 4 }, "state_sprawl" => true)
    expect(rules.enabled?("feature_envy")).to(be(false))
    expect(rules.enabled?("complexity")).to(be(true))
    expect(rules.threshold("complexity", 10)).to(eq(4))
    expect(rules.threshold("state_sprawl", 4)).to(eq(4))
    expect(parse("complexity" => { "enabled" => false }).enabled?("complexity")).to(be(false))
  end

  it "leaves measured kinds on and low-precision kinds off when nothing is said, and all of them on for all" do
    defaults = Hashira::Config::Rules::NONE
    expect(%w[complexity duplication nil_check].map { defaults.enabled?(it) }).to(eq([true, true, false]))
    expect(defaults.threshold("complexity", 10)).to(eq(10))
    expect(%w[nil_check indirection].map { parse("all").enabled?(it) }).to(eq([true, true]))
    expect(parse("nil_check" => true).enabled?("nil_check")).to(be(true))
    expect(defaults.naming(%w[nil_check]).enabled?("nil_check")).to(be(true))
  end

  it "refuses what it cannot apply" do
    {
      ["complexity"] => "checks takes all, or kind: settings",
      { "envy" => false } => 'unknown kind "envy"',
      { "complexity" => "off" } => "complexity takes true, false or { threshold: N }",
      { "complexity" => { "limit" => 3 } } => 'complexity has no setting "limit"',
      { "feature_envy" => { "threshold" => 3 } } => "no threshold (thresholds: boundary_sprawl, complexity,",
      { "complexity" => { "threshold" => 0 } } => "threshold must be a positive whole number",
      { "complexity" => { "threshold" => "3" } } => "threshold must be a positive whole number"
    }.each { |raw, message| expect { parse(raw) }.to(raise_error(Hashira::Error, /#{Regexp.escape(message)}/)) }
  end
end
