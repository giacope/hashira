# frozen_string_literal: true

require "prism"

class Hashira::Smells::ManualDispatch < Hashira::Smells::Check
  PROTOCOL = :respond_to_missing?

  private

  def smelly? = subject.node.name != PROTOCOL && sightings.any?

  def sightings
    @_sightings ||= Hashira::Smells::Scope.inside(subject.node)
      .select { it.is_a?(Prism::CallNode) && it.name == :respond_to? }
  end

  def detail = { site: spots(sightings) }
end
