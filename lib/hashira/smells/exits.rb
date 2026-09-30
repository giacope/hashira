# frozen_string_literal: true

require "prism"
require_relative "tails"

class Hashira::Smells::Exits
  FLOWING = Hashira::Smells::Tails.new(Hashira::Smells::Tails::FLOW)

  def initialize(definition)
    @definition = definition
  end

  def include?(node) = exits.include?(node)

  private

  def exits = @_exits ||= FLOWING.reach([@definition.body].compact + returned)

  def returned = returns.flat_map { Array(it.arguments&.arguments) }

  def returns = Hashira::Smells::Scope.inside(@definition).grep(Prism::ReturnNode)
end
