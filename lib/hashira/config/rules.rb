# frozen_string_literal: true

class Hashira::Config::Rules
  THRESHOLDS = %w[
    boundary_sprawl complexity indirection low_cohesion middle_man repeated_conditional state_sprawl wide_edge
  ].freeze

  OPT_IN = %w[
    assumed_state boundary_sprawl control_parameter data_clump feature_envy indirection manual_dispatch
    module_initialize nil_check repeated_call repeated_conditional state_sprawl utility_function
    concrete_inheritance data_class low_cohesion message_chain middle_man refused_bequest
  ].freeze

  EVERY = "all"

  def self.parse(raw, kinds)
    return Hashira::Config::Rules::ALL if raw == EVERY
    raise(Hashira::Error, "checks takes all, or kind: settings, not #{raw.inspect}") unless raw.is_a?(Hash)
    new(raw.to_h { |kind, setting| Hashira::Config::Rule.parse(kind, setting, kinds) })
  end

  def initialize(table, chosen = OPT_IN)
    @table = table
    @chosen = chosen
  end

  def enabled?(kind) = rule(kind).enabled

  def threshold(kind, default) = rule(kind).threshold || default

  def limit(kind, name, default) = rule(kind).limits.fetch(name, default)

  def naming(kinds) = Hashira::Config::Rules.new(@table, @chosen - kinds)

  private

  def rule(kind) = @table.fetch(kind) { fallback(kind) }

  def fallback(kind) = @chosen.include?(kind) ? Hashira::Config::Rule::OFF : Hashira::Config::Rule::ON
end

Hashira::Config::Rules::NONE = Hashira::Config::Rules.new({})

Hashira::Config::Rules::ALL = Hashira::Config::Rules.new({}, [])
