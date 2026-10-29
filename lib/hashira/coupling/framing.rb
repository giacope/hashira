# frozen_string_literal: true

class Hashira::Coupling::Framing
  def initialize(heritage, hosting, routines, marks)
    @heritage = heritage
    @hosting = hosting
    @routines = routines
    @marks = marks
  end

  def framed?(routine) = [routine, *forebears(routine)].any? { it.hooked?(@hosting) }

  def open?(owner) = @heritage.lineage(owner).any? { @marks.opened?(it) }

  private

  def forebears(routine)
    owner, *mark = routine.to_a
    @heritage.lineage(owner).drop(1).flat_map { selectors.fetch([it, *mark], []) }
  end

  def selectors = @_selectors ||= @routines.group_by(&:to_a)
end
