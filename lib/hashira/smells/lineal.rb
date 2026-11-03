# frozen_string_literal: true

require_relative "check"

class Hashira::Smells::Lineal < Hashira::Smells::Check
  def self.build(subject, rules, family) = new(subject, rules, family)

  def initialize(subject, rules, family)
    super(subject, rules)
    @family = family
  end

  private

  attr_reader :family
end
