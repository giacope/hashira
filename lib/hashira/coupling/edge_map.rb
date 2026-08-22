# frozen_string_literal: true

class Hashira::Coupling::EdgeMap
  NONE = Set.new.freeze

  def initialize(census)
    @census = census
  end

  def dependencies = @_dependencies ||= {}

  def outgoing(package) = dependencies.fetch(package, NONE)

  def evidence(edge) = evidences.fetch(edge, NONE)

  def usage(edge) = usages.fetch(edge, NONE)

  def sources(edge) = homes.fetch(edge, NONE)

  def record(source, file, tree)
    Hashira::Coupling::References.new(@census.roots).sightings(tree).each do |segments, line, nesting, home|
      note(@census.charge(file, home), locate(segments, nesting), segments, source, line)
    end
  end

  private

  def evidences = @_evidences ||= {}

  def usages = @_usages ||= {}

  def homes = @_homes ||= {}

  def locate(segments, nesting)
    nesting ? @census.resolve(segments, nesting) : @census.pinpoint(segments)
  end

  def note(from, to, segments, source, line)
    return unless to && to != from
    add(dependencies, from, to)
    chart(Hashira::Coupling::Edge.new(from, to), segments, source, line)
  end

  def chart(edge, segments, source, line)
    add(evidences, edge, "#{source}:#{line}: #{segments.join("::")}")
    add(usages, edge, @census.holder(segments))
    add(homes, edge, source)
  end

  def add(store, key, value) = (store[key] ||= Set.new) << value
end
