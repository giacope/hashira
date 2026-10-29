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

  def initialize(table, reserve = HELD)
    @table = table
    @reserve = reserve
  end

  def strict? = @reserve.strict?

  def enabled?(kind) = rule(kind).enabled?

  def limit(kind, name, default) = rule(kind).limit(name, default)

  def chosen(named: [], kinds: [], every: [], strict: false)
    reserve = @reserve.naming(named)
    Hashira::Config::Rules.new(narrowed(kinds, every), strict ? reserve.tightened : reserve)
  end

  ALL = new({}, OPEN)

  private

  def narrowed(kinds, every)
    return @table if kinds.empty?
    (every.to_a - kinds).to_h { [it, OFF] }.merge(@table.slice(*kinds))
  end

  def rule(kind) = @table.fetch(kind) { fallback(kind) }

  def fallback(kind) = @reserve.held?(kind) ? OFF : ON
end
