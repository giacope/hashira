# frozen_string_literal: true

class Hashira::Smells::Defaults
  def initialize(definition)
    @node = definition
  end

  def to_a = [@node.parameters].compact.flat_map { [it] + Hashira::Smells::Scope.new(it).inside }
end
