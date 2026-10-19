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
      note(@census.charge(file, home), locate(segments, nesting), segments, "#{source}:#{line}")
    end
    (@_pledges ||= {}).merge!(references.guarantees.to_h { |at, said| ["#{source}:#{at}", "#{source}:#{said}"] })
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
