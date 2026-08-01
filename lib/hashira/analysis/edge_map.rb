# frozen_string_literal: true

class Hashira::Analysis::EdgeMap
  def initialize(project, census)
    @project = project
    @census = census
    @dependencies = sets
    @evidence = sets
  end

  attr_reader :dependencies, :evidence

  def record(file, tree)
    source = @project.relative(file)
    Hashira::Analysis::References.sightings(tree, @census.roots).each do |segments, line, nesting, home|
      note(@census.charge(file, home), locate(segments, nesting), "#{source}:#{line}: #{segments.join("::")}")
    end
  end

  private

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def locate(segments, nesting)
    nesting ? @census.resolve(segments, nesting) : @census.pinpoint(segments)
  end

  def note(from, to, sighting)
    return unless to && to != from
    @dependencies[from] << to
    @evidence[[from, to]] << sighting
  end
end
