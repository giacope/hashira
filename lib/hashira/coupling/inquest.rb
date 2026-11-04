# frozen_string_literal: true

class Hashira::Coupling::Inquest
  def initialize(spoken, marks, anchors, hosting)
    @spoken = spoken
    @marks = marks
    @anchors = anchors
    @hosting = hosting
  end

  def dead(constants, routines, heritage)
    exposure = Hashira::Coupling::Exposure.new(constants)
    framing = Hashira::Coupling::Framing.new(heritage, @hosting, routines, @marks)
    buried(constants) + routines.select { it.dead?(@spoken, @anchors, exposure, framing) }
  end

  private

  def buried(constants)
    dead = constants.reject { |constant| constant.live?(@spoken, @marks) || holding?(constants, constant.to_a) }
    names = dead.to_set(&:to_a)
    dead.reject { |constant| nested?(names, constant.to_a) }
  end

  def holding?(constants, path) = held(constants).any? { it.first(path.size) == path }

  def held(constants) = @_held ||= constants.select { it.held?(@anchors, @hosting) }.map(&:to_a)

  def nested?(names, path) = (1...path.size).any? { names.include?(path.first(it)) }
end
