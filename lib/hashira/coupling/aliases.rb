# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Aliases
  BODIES = [[%w[Class], :new], [%w[Struct], :new], [%w[Data], :define]].freeze

  def initialize(openings)
    @openings = openings
  end

  def of(path) = values[path]

  private

  def values
    @_values ||= @openings.flat_map(&:assignments).reject { built?(it[1]) }.to_h { |path, *value| [path, value] }
  end

  def built?(value)
    value.is_a?(Prism::CallNode) && BODIES.include?([Hashira::Analysis::Syntax.segments(value.receiver), value.name])
  end
end
