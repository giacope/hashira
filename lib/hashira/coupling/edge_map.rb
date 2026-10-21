# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  Link =
    Data.define(:from, :to, :site, :macro) do
      def said = site.sub(": ", ": #{macro} ")

      def anchor = site[/\A.+?:\d+/]

      def line = site[/:(\d+):/, 1].to_i
    end

  def initialize(census)
    @census = census
  end

  def dependencies = @_dependencies ||= sets

  def evidence = @_evidence ||= sets

  def usage = @_usage ||= sets

  def pledges = @_pledges.to_h

  def declared = @_declared ||= {}

  def links = @_links ||= []

  def record(source, file, tree)
    references = Hashira::Coupling::References.new(@census.roots, @census.associations)
    references.sightings(tree).each { sighted(source, file, it) }
    (@_pledges ||= {}).merge!(references.guarantees.to_h { |at, said| ["#{source}:#{at}", "#{source}:#{said}"] })
  end

  private

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def sighted(source, file, sighting)
    segments, line, nesting, home, macro = sighting
    site = "#{source}:#{line}"
    said = note(@census.charge(file, home), segments, nesting, site)
    return unless macro
    named = "#{site}: #{segments.join("::")}"
    declared[said] = named.sub(": ", ": #{macro} ")
    link(home.last, @census.locate(segments, nesting || []), named, macro)
  end

  def link(from, to, site, macro)
    links << Link.new(from: @census.strip(from).join("::"), to: to.join("::"), site:, macro:) if from && to
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
