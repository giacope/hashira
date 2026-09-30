# frozen_string_literal: true

class Hashira::Coupling::Scope
  def initialize(registry, catalog, placement)
    @registry = registry
    @catalog = catalog
    @placement = placement
  end

  def resolve(segments, nesting)
    return if @placement.skip?(segments)
    found = bind(Hashira::Coupling::Lineage::Link.new(segments:, nesting:), 1)
    qualify(found && @registry.exact(found))
  end

  def pinpoint(segments) = resolve(segments, [])

  private

  def bind(link, reach)
    segments, nesting = link.deconstruct
    [*nesting.reverse, *ancestors(nesting.last), []].lazy.filter_map { descend(it, segments, reach) }.first
  end

  def descend(entry, segments, reach)
    segments.length.downto(reach).lazy.map { @catalog.strip(entry + segments.first(it)) }.find { known?(it) }
  end

  def known?(path) = @registry.exact(path) && @catalog.territory.owned?(path)

  def ancestors(innermost) = innermost ? lineage(@catalog.strip(innermost)) : []

  def lineage(path)
    return ancestry[path] if ancestry.key?(path)
    ancestry[path] = []
    ancestry[path] = climb(path)
  end

  def ancestry = @_ancestry ||= {}

  def climb(path) = parents(path).flat_map { [it, *lineage(it)] }.uniq

  def parents(path) = @catalog.lineage.parents(path).filter_map { bind(it, it.reach) }

  def qualify(found) = (found unless found == Hashira::Coupling::ConstantRegistry::AMBIGUOUS)
end
