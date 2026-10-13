# frozen_string_literal: true

class Hashira::Config::Rules
  THRESHOLDS = %w[boundary_sprawl complexity indirection repeated_conditional state_sprawl wide_edge].freeze

  def self.parse(raw, kinds)
    raise(Hashira::Error, "checks takes kind: settings, not #{raw.inspect}") unless raw.is_a?(Hash)
    new(raw.to_h { |kind, setting| Hashira::Config::Rule.parse(kind, setting, kinds) })
  end

  def initialize(table)
    @table = table
  end

  def enabled?(kind) = @table.fetch(kind, Hashira::Config::Rule::ON).enabled

  def threshold(kind, default) = @table.fetch(kind, Hashira::Config::Rule::ON).threshold || default

  def disabled = @table.reject { |_kind, rule| rule.enabled }.keys
end

Hashira::Config::Rules::NONE = Hashira::Config::Rules.new({})
