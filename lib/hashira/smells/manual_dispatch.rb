# frozen_string_literal: true

require "prism"

class Hashira::Smells::ManualDispatch < Hashira::Smells::Check
  private

  def smelly? = sightings.any?

  def sightings
    @sightings ||= Hashira::Smells::Scope.inside(subject.node)
      .select { it.is_a?(Prism::CallNode) && it.name == :respond_to? }
  end

  def message
    "#{label} dispatches manually via respond_to? " \
      "(#{subject.file}:#{sightings.map { it.location.start_line }.uniq.join(", ")}). " \
      "Trust the duck type, or split the callers into two adapters."
  end
end
