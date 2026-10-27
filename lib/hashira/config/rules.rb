# frozen_string_literal: true

class Hashira::Config::Rules
  THRESHOLDS = %w[
    boundary_sprawl complexity indirection low_cohesion middle_man repeated_conditional state_sprawl wide_edge
  ].freeze

  OPT_IN = %w[boundary_sprawl indirection middle_man repeated_conditional].freeze

  HISTORY = %w[change_coupling].freeze

  CHOSEN = (OPT_IN + HISTORY).freeze

  STRICT = %w[stateful_mixin].freeze

  HELD = Hashira::Config::Reserve.new(kinds: CHOSEN, strict: false)

  OPEN = HELD.with(kinds: [])

  EVERY = "all"

  def self.parse(raw, kinds)
    return Hashira::Config::Rules::ALL if raw == EVERY
    raise(Hashira::Error, "checks takes all, or kind: settings, not #{raw.inspect}") unless raw.is_a?(Hash)
    every = raw.fetch(EVERY, false)
    raise(Hashira::Error, "checks: all takes true or false, not #{every.inspect}") unless [true, false].include?(every)
    new(
      raw.except(EVERY).to_h do |kind, setting|
        Hashira::Config::Rule.parse(kind, setting, kinds)
      end, every ? OPEN : HELD
    )
  end

  def initialize(table, reserve = HELD, layers = Hashira::Config::Layers::NONE, boundaries = [])
    @table = table
    @reserve = reserve
    @layers = layers
    @boundaries = boundaries
  end

  attr_reader :layers, :boundaries

  def strict? = @reserve.strict

  def enabled?(kind) = rule(kind).enabled

  def threshold(kind, default) = rule(kind).threshold || default

  def limit(kind, name, default) = rule(kind).limits.fetch(name, default)

  def naming(kinds) = remade(reserve: @reserve.naming(kinds))

  def narrowed(kinds, every)
    return self if kinds.empty?
    silenced = (every - kinds).to_h { [it, Hashira::Config::Rule::OFF] }
    remade(table: silenced.merge(@table.slice(*kinds)))
  end

  def layered(layers) = remade(layers:)

  def bounded(boundaries) = remade(boundaries:)

  def tightened = remade(reserve: @reserve.with(strict: true))

  private

  def remade(table: @table, reserve: @reserve, layers: @layers, boundaries: @boundaries)
    Hashira::Config::Rules.new(table, reserve, layers, boundaries)
  end

  def rule(kind) = @table.fetch(kind) { fallback(kind) }

  def fallback(kind) = @reserve.held?(kind) ? Hashira::Config::Rule::OFF : Hashira::Config::Rule::ON
end

Hashira::Config::Rules::NONE = Hashira::Config::Rules.new({})

Hashira::Config::Rules::ALL = Hashira::Config::Rules.new({}, Hashira::Config::Rules::OPEN)
