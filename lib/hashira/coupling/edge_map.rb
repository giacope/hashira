# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  def initialize(scope, ledger, catalog, reading)
    @scope = scope
    @ledger = ledger
    @catalog = catalog
    @reading = reading
  end

  def to_h = dependencies

  def to_a = links.map { |ends, site, macro| Hashira::Coupling::Link.new(ends, site, macro, pledges) }

  def [](from, to) = evidence.fetch([from, to]) { Set.new }

  def usage(from, to) = used.fetch([from, to])

  def constants(from, to)
    names = usage(from, to)
    names.reject { |name| names.any? { inside?(name, it) } }.sort
  end

  def guarantees(from, to) = noted(from, to, pledges)

  def declarations(from, to) = noted(from, to, declared)

  private

  def recorded
    return @_recorded if @_recorded
    @_recorded = [sets, sets, sets, []]
    @reading.each { |source, file, tree, references| record(source, file, tree, references) }
    @_recorded
  end

  def dependencies = recorded.fetch(0)

  def evidence = recorded.fetch(1)

  def used = recorded.fetch(2)

  def links = recorded.fetch(3)

  def pledges = @_pledges ||= {}

  def declared = @_declared ||= {}

  def sets = Hash.new { |hash, key| hash[key] = Set.new }

  def record(source, file, tree, references)
    references.sightings(tree).each { sighted(source, file, it) }
    pledges.merge!(references.guarantees.to_h { |at, said| ["#{source}:#{at}", "#{source}:#{said}"] })
  end

  def noted(from, to, notes) = self[from, to].filter_map { notes[it] }

  def sighted(source, file, sighting)
    segments, line, nesting, home, macro = sighting
    site = "#{source}:#{line}"
    said = note(@ledger.charge(file, home, @scope.locate(segments, nesting || [])), segments, nesting, site)
    return unless macro
    named = "#{site}: #{segments.join("::")}"
    declared[said] = named.sub(": ", ": #{macro} ")
    link(home.last, @scope.locate(segments, nesting || []), named, macro)
  end

  def link(from, to, site, macro)
    links << [[@catalog.strip(from).join("::"), to.join("::")], site, macro] if from && to
  end

  def locate(segments, nesting)
    nesting ? @scope.resolve(segments, nesting) : @scope.pinpoint(segments)
  end

  def note(from, segments, nesting, site)
    to = locate(segments, nesting)
    return unless to && to != from
    dependencies[from] << to
    used[[from, to]] << @ledger.holder(@scope.locate(segments, nesting || []))
    "#{site}: #{segments.join("::")}".tap { evidence[[from, to]] << it }
  end

  def inside?(name, outer) = name.start_with?("#{outer}::") && classes.include?(outer)

  def classes = @_classes ||= @catalog.select { it.form.klass? }.to_set { it.to_a.join("::") }
end
