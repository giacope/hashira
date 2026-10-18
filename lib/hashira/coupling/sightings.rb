# frozen_string_literal: true

class Hashira::Coupling::Sightings
  Sighting =
    Data.define(:file, :from, :path, :site, :label) do
      def name = path.join("::")

      def evidence = "#{site}: #{label}"
    end

  def initialize(project, trees, census)
    @project = project
    @trees = trees
    @census = census
  end

  def to_a = @_to_a ||= @trees.flat_map { |file, tree| seen(file, tree) }

  private

  def seen(file, tree)
    source = @project.relative(file)
    references = Hashira::Coupling::References.new(@census.roots, @census.associations)
    references.sightings(tree).filter_map do |segments, line, nesting, home|
      path = @census.locate(segments, nesting || [])
      next unless path
      Sighting.new(
        file:, from: @census.charge(file, home), path:, site: "#{source}:#{line}",
        label: segments.join("::")
      )
    end
  end
end
