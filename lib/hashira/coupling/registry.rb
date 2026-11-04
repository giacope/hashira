# frozen_string_literal: true

class Hashira::Coupling::Registry
  HOOK = "inherited"

  def initialize(heritage, routines, registries, openings)
    @heritage = heritage
    @routines = routines
    @registries = registries
    @openings = openings
  end

  def registered?(path)
    @heritage.lineage(path).drop(1).any? { inheriting.include?(it) || @registries.include?(it.last) }
  end

  def loaded?(path) = @openings.loads?(path)

  private

  def inheriting = @_inheriting ||= @routines.map(&:to_a).select { it.last == HOOK }.to_set(&:first)
end
