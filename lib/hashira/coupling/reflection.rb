# frozen_string_literal: true

class Hashira::Coupling::Reflection
  def initialize(reflected, census, openings)
    @reflected = reflected
    @census = census
    @openings = openings
  end

  def reached?(path) = roots.any? { path.size > it.size && path.first(it.size) == it }

  private

  def roots = @_roots ||= @reflected.filter_map { |owner, segments| owner ? homes[owner] : locate(segments) }

  def locate(segments) = @census.locate(segments, [])

  def homes = @_homes ||= @openings.to_h { [it.node, it.path] }.compare_by_identity
end
