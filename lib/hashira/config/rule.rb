# frozen_string_literal: true

module Hashira
  module Config
    Rule =
      Data.define(:enabled, :threshold, :limits) do
        def initialize(limits: {}, **) = super

        def self.parse(kind, setting, kinds)
          raise(Error, "checks: unknown kind #{kind.inspect} (use: #{kinds.join(", ")})") unless kinds.include?(kind)
          [kind, Setting.new(kind, setting.is_a?(Hash) ? setting : Switch.new(kind, setting).to_h).rule]
        end
      end

    Rule::ON = Rule.new(enabled: true, threshold: nil)
    Rule::OFF = Rule.new(enabled: false, threshold: nil)

    Switch =
      Data.define(:kind, :setting) do
        def to_h
          return { "enabled" => setting } if [true, false].include?(setting)
          raise(Error, "checks: #{kind} takes true, false or { threshold: N }, not #{setting.inspect}")
        end
      end
  end
end
