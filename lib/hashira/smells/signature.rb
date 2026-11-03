# frozen_string_literal: true

class Hashira::Smells::Signature
  def initialize(definition)
    @node = definition
  end

  def name = @node.name

  def line = @node.location.start_line

  def arity = Array(@node.parameters&.requireds).size
end
