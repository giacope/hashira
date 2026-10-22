# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Aliases
  def initialize(openings)
    @openings = openings
  end

  def of(path) = values[path]

  private

  def values
    @_values ||= @openings.flat_map(&:assignments).reject { built?(it[1]) }.to_h { |path, *value| [path, value] }
  end

  def built?(value) = Hashira::Coupling::Body.new(value).built?
end
