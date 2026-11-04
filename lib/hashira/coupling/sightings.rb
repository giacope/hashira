# frozen_string_literal: true

class Hashira::Coupling::Sightings
  def initialize(reading, scope, ledger, catalog)
    @reading = reading
    @scope = scope
    @ledger = ledger
    @catalog = catalog
  end

  def to_a = @_to_a ||= seen

  def code = Hashira::Coupling::Code.new(self, @reading, @ledger)

  def lookup = Hashira::Coupling::Lookup.new(@scope, @catalog)

  private

  def seen
    found = []
    @reading.each { |source, file, tree, references| found.concat(sighted(source, file, tree, references)) }
    found
  end

  def sighted(source, file, tree, references)
    references.sightings(tree).filter_map do |segments, line, nesting, home|
      path = @scope.locate(segments, nesting || [])
      next unless path
      said = Hashira::Coupling::Said.new("#{source}:#{line}", segments.join("::"), holder(nesting, source))
      Hashira::Coupling::Sighting.new(file, @ledger.charge(file, home, path), path, said)
    end
  end

  def holder(nesting, source)
    inner = Array(nesting).last
    if inner
      @catalog.strip(inner).join("::").then { it.empty? ? inner.join("::") : it }
    else
      source
    end
  end
end
