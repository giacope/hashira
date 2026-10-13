# frozen_string_literal: true

RSpec.describe(Hashira::Config::Rules) do
  def parse(raw) = described_class.parse(raw, %w[complexity feature_envy state_sprawl])

  it "turns kinds off and moves thresholds" do
    rules = parse("feature_envy" => false, "complexity" => { "threshold" => 4 }, "state_sprawl" => true)
    expect(rules.enabled?("feature_envy")).to(be(false))
    expect(rules.enabled?("complexity")).to(be(true))
    expect(rules.threshold("complexity", 10)).to(eq(4))
    expect(rules.threshold("state_sprawl", 4)).to(eq(4))
    expect(rules.disabled).to(eq(["feature_envy"]))
    expect(parse("complexity" => { "enabled" => false }).enabled?("complexity")).to(be(false))
  end

  it "leaves every kind on at its default when nothing is said" do
    expect(Hashira::Config::Rules::NONE.enabled?("complexity")).to(be(true))
    expect(Hashira::Config::Rules::NONE.threshold("complexity", 10)).to(eq(10))
  end

  it "refuses what it cannot apply" do
    {
      ["complexity"] => "checks takes kind: settings",
      { "envy" => false } => 'unknown kind "envy"',
      { "complexity" => "off" } => "complexity takes true, false or { threshold: N }",
      { "complexity" => { "limit" => 3 } } => 'complexity has no setting "limit"',
      { "feature_envy" => { "threshold" => 3 } } => "feature_envy has no threshold",
      { "complexity" => { "threshold" => 0 } } => "threshold must be a positive whole number",
      { "complexity" => { "threshold" => "3" } } => "threshold must be a positive whole number"
    }.each { |raw, message| expect { parse(raw) }.to(raise_error(Hashira::Error, /#{Regexp.escape(message)}/)) }
  end
end
