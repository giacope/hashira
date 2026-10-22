# frozen_string_literal: true

class Hashira::Config::Setting
  KEYS = %w[enabled threshold].freeze

  LIMITS = { "fragmentation" => %w[helpers lines], "change_coupling" => %w[commits degree files] }.freeze

  LISTS = { "dead_code" => %w[roots] }.freeze

  def initialize(kind, raw)
    @kind = kind
    @raw = raw
  end

  def rule
    keys = KEYS + named + listed
    stray = (@raw.keys - keys).first
    raise(Hashira::Error, "checks: #{@kind} has no setting #{stray.inspect} (use: #{keys.join(", ")})") if stray
    Hashira::Config::Rule.new(enabled: @raw["enabled"] != false, threshold:, limits:)
  end

  private

  def named = LIMITS.fetch(@kind, [])

  def listed = LISTS.fetch(@kind, [])

  def limits
    chosen = (named + listed).select { @raw.key?(it) }
    chosen.to_h { [it, listed.include?(it) ? words(it) : measured(it)] }
  end

  def words(name)
    value = Array(@raw[name])
    return value if value.all? { it.is_a?(String) && !it.empty? }
    raise(Hashira::Error, "checks: #{@kind} #{name} takes a list of names")
  end

  def measured(name)
    value = @raw[name]
    return value if value.is_a?(Numeric) && value.positive?
    raise(Hashira::Error, "checks: #{@kind} #{name} must be a positive number")
  end

  def threshold
    return unless @raw.key?("threshold")
    value = @raw["threshold"]
    scale = Hashira::Config::Rules::THRESHOLDS.join(", ")
    raise(Hashira::Error, "checks: #{@kind} has no threshold (thresholds: #{scale})") unless scaled?
    whole?(value) ? value : raise(Hashira::Error, "checks: #{@kind} threshold must be a positive whole number")
  end

  def scaled? = Hashira::Config::Rules::THRESHOLDS.include?(@kind)

  def whole?(value) = value.is_a?(Integer) && value.positive?
end
