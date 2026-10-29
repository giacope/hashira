# frozen_string_literal: true

class Hashira::Config::Rules
  OPT_IN = %w[boundary_sprawl indirection middle_man repeated_conditional].freeze

  HISTORY = %w[change_coupling].freeze

  CHOSEN = (OPT_IN + HISTORY).freeze

  HELD = Hashira::Config::Reserve.new(CHOSEN, strict: false)

  OPEN = Hashira::Config::Reserve.new([], strict: false)

  ON = Hashira::Config::Rule.new(enabled: true)

  OFF = Hashira::Config::Rule.new(enabled: false)

  EVERY = "all"

  private_constant :OPT_IN, :HISTORY, :CHOSEN, :HELD, :OPEN, :ON, :OFF, :EVERY

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

  def initialize(table, reserve = HELD, layers = Hashira::Config::Layers.new([]), boundaries = [])
    @table = table
    @reserve = reserve
    @layers = layers
    @boundaries = boundaries
  end

  attr_reader :layers, :boundaries

  def strict? = @reserve.strict?

  def enabled?(kind) = rule(kind).enabled?

  def threshold(kind, default) = rule(kind).limit("threshold", default)

  def limit(kind, name, default) = rule(kind).limit(name, default)

  def naming(kinds) = remade(reserve: @reserve.naming(kinds))

  def narrowed(kinds, every)
    return self if kinds.empty?
    silenced = (every.to_a - kinds).to_h { [it, OFF] }
    remade(table: silenced.merge(@table.slice(*kinds)))
  end

  def layered(layers) = remade(layers:)

  def bounded(boundaries) = remade(boundaries:)

  def tightened = remade(reserve: @reserve.tightened)

  ALL = new({}, OPEN)

  private

  def remade(table: @table, reserve: @reserve, layers: @layers, boundaries: @boundaries)
    Hashira::Config::Rules.new(table, reserve, layers, boundaries)
  end

  def rule(kind) = @table.fetch(kind) { fallback(kind) }

  def fallback(kind) = @reserve.held?(kind) ? OFF : ON
end
