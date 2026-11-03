# frozen_string_literal: true

class Hashira::Smells::Imprint
  def initialize(type)
    @node = type
  end

  def to_a = [@node.body].compact.flat_map { Hashira::Smells::Marks.new(it).to_a }
end
