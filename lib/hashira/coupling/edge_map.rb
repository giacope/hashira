# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  def initialize(census)
    @census = census
  end

  def dependencies = @_dependencies ||= sets

  def evidence = @_evidence ||= sets

  def usage = @_usage ||= sets

  def pledges = @_pledges.to_h

  def record(source, file, tree)
    references = Hashira::Coupling::References.new(@census.roots, @census.associations)
    references.sightings(tree).each do |segments, line, nesting, home|
      note(@census.charge(file, home), segments, nesting, "#{source}:#{line}")
    end
    (@_pledges ||= {}).merge!(references.guarantees.to_h { |at, said| ["#{source}:#{at}", "#{source}:#{said}"] })
  end

  private

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def locate(segments, nesting)
    nesting ? @census.resolve(segments, nesting) : @census.pinpoint(segments)
  end

  def note(from, segments, nesting, site)
    to = locate(segments, nesting)
    return unless to && to != from
    dependencies[from] << to
    evidence[[from, to]] << "#{site}: #{segments.join("::")}"
    usage[[from, to]] << @census.holder(@census.locate(segments, nesting || []))
  end
end
