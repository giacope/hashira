# frozen_string_literal: true

class Hashira::Coupling::Lineage
  def initialize(definitions)
    @definitions = definitions
  end

  def parents(path) = links.fetch(path, [])

  private

  def links
    @_links ||= @definitions.group_by(&:to_a).transform_values { |openings| openings.flat_map { it.kin.to_a } }
  end
end
