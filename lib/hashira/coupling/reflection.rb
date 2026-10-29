# frozen_string_literal: true

class Hashira::Coupling::Reflection
  def initialize(reflected, census, openings)
    @reflected = reflected
    @census = census
    @openings = openings
  end

  def reached?(path) = roots.any? { path.size > it.size && path.first(it.size) == it }

  private

  def roots
    @_roots ||=
      @reflected.filter_map do |owner, segments|
        segments ? @census.locate(segments, @openings.nest(owner)) : @openings.home(owner).first
      end
  end
end
