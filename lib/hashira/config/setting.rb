# frozen_string_literal: true

class Hashira::Config::Setting
  KEYS = %w[enabled threshold].freeze

  def initialize(kind, raw)
    @kind = kind
    @raw = raw
  end

  def rule
    stray = (@raw.keys - KEYS).first
    raise(Hashira::Error, "checks: #{@kind} has no setting #{stray.inspect} (use: #{KEYS.join(", ")})") if stray
    Hashira::Config::Rule.new(enabled: @raw["enabled"] != false, threshold:)
  end

  private

  def threshold
    return unless @raw.key?("threshold")
    value = @raw["threshold"]
    raise(Hashira::Error, "checks: #{@kind} has no threshold (thresholds: #{scale})") unless scaled?
    whole?(value) ? value : raise(Hashira::Error, "checks: #{@kind} threshold must be a positive whole number")
  end

  def scaled? = Hashira::Config::Rules::THRESHOLDS.include?(@kind)

  def whole?(value) = value.is_a?(Integer) && value.positive?

  def scale = Hashira::Config::Rules::THRESHOLDS.join(", ")
end
