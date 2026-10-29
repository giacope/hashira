# frozen_string_literal: true

class Hashira::CLI::Draft
  def initialize(rules, layers, boundaries)
    @rules = rules
    @layers = layers
    @boundaries = boundaries
  end

  def chosen(**choices) = Hashira::CLI::Draft.new(@rules.chosen(**choices), @layers, @boundaries)

  def call(scope, record, notices)
    scope.pipeline(scope.project(record, @boundaries), @rules, @layers, notices)
  end

  def to_h = { rules: @rules, layers: @layers }
end
