# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  def initialize(census)
    @census = census
  end

  def dependencies = @dependencies ||= sets

  def evidence = @evidence ||= sets

  def usage = @usage ||= sets

  def record(source, file, tree)
    Hashira::Coupling::References.new(@census.roots).sightings(tree).each do |segments, line, nesting, home|
      note(@census.charge(file, home), locate(segments, nesting), segments, "#{source}:#{line}")
    end
  end

  private

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def locate(segments, nesting)
    nesting ? @census.resolve(segments, nesting) : @census.pinpoint(segments)
  end

  def note(from, to, segments, site)
    return unless to && to != from
    dependencies[from] << to
    evidence[[from, to]] << "#{site}: #{segments.join("::")}"
    usage[[from, to]] << @census.holder(segments)
  end
end
