# frozen_string_literal: true

class Hashira::Config::Rules
  THRESHOLDS = %w[
    boundary_sprawl complexity indirection low_cohesion middle_man repeated_conditional state_sprawl wide_edge
  ].freeze

  OPT_IN = %w[boundary_sprawl indirection middle_man repeated_conditional].freeze

  HISTORY = %w[change_coupling].freeze

  CHOSEN = (OPT_IN + HISTORY).freeze

  EVERY = "all"

  def self.parse(raw, kinds)
    return Hashira::Config::Rules::ALL if raw == EVERY
    raise(Hashira::Error, "checks takes all, or kind: settings, not #{raw.inspect}") unless raw.is_a?(Hash)
    every = raw.fetch(EVERY, false)
    raise(Hashira::Error, "checks: all takes true or false, not #{every.inspect}") unless [true, false].include?(every)
    new(
      raw.except(EVERY).to_h do |kind, setting|
        Hashira::Config::Rule.parse(kind, setting, kinds)
      end, every ? [] : CHOSEN
    )
  end

  def initialize(table, chosen = CHOSEN, layers = Hashira::Config::Layers::NONE)
    @table = table
    @chosen = chosen
    @layers = layers
  end

  attr_reader :layers

  def enabled?(kind) = rule(kind).enabled

  def threshold(kind, default) = rule(kind).threshold || default

  def limit(kind, name, default) = rule(kind).limits.fetch(name, default)

  def naming(kinds) = Hashira::Config::Rules.new(@table, @chosen - kinds, @layers)

  def layered(layers) = Hashira::Config::Rules.new(@table, @chosen, layers)

  private

  def rule(kind) = @table.fetch(kind) { fallback(kind) }

  def fallback(kind) = @chosen.include?(kind) ? Hashira::Config::Rule::OFF : Hashira::Config::Rule::ON
end

Hashira::Config::Rules::NONE = Hashira::Config::Rules.new({})

Hashira::Config::Rules::ALL = Hashira::Config::Rules.new({}, [])
