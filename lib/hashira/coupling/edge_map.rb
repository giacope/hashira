# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  def initialize(census)
    @census = census
  end

  def dependencies = @_dependencies ||= sets

  def evidence = @_evidence ||= sets

  def usage = @_usage ||= sets

  def pledges = @_pledges.to_h

  def declared = @_declared ||= {}

  def record(source, file, tree)
    references = Hashira::Coupling::References.new(@census.roots, @census.associations)
    references.sightings(tree).each { sighted(source, file, it) }
    (@_pledges ||= {}).merge!(references.guarantees.to_h { |at, said| ["#{source}:#{at}", "#{source}:#{said}"] })
  end

  private

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def sighted(source, file, sighting)
    segments, line, nesting, home, macro = sighting
    said = note(@census.charge(file, home), segments, nesting, "#{source}:#{line}")
    declared[said] = "#{source}:#{line}: #{macro} #{segments.join("::")}" if said && macro
  end

  def locate(segments, nesting)
    nesting ? @census.resolve(segments, nesting) : @census.pinpoint(segments)
  end

  def note(from, segments, nesting, site)
    to = locate(segments, nesting)
    return unless to && to != from
    dependencies[from] << to
    usage[[from, to]] << @census.holder(@census.locate(segments, nesting || []))
    "#{site}: #{segments.join("::")}".tap { evidence[[from, to]] << it }
  end
end
