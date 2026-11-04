# frozen_string_literal: true

class Hashira::Coupling::Reflection
  def initialize(reflected, lookup, openings)
    @reflected = reflected
    @lookup = lookup
    @openings = openings
  end

  def reached?(path) = roots.any? { path.size > it.size && path.first(it.size) == it }

  private

  def roots
    @_roots ||=
      @reflected.filter_map do |owner, segments|
        segments ? @lookup.locate(segments, @openings.nest(owner)) : @openings.home(owner).first
      end
  end
end
