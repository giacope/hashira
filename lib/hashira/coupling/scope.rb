# frozen_string_literal: true

class Hashira::Coupling::Scope
  def initialize(registry, catalog, placement)
    @registry = registry
    @catalog = catalog
    @placement = placement
  end

  def resolve(segments, nesting)
    return if @placement.skip?(segments)
    found = locate(segments, nesting)
    owner(found) if found
  end

  def owner(path) = qualify(@registry.exact(path))

  def locate(segments, nesting) = bind(Hashira::Coupling::Lineage::Link.new(segments:, nesting:), 1)

  def pinpoint(segments) = resolve(segments, [])

  def vias = @_vias ||= Hash.new { |hash, path| hash[path] = Set.new }

  private

  def bind(link, reach)
    segments, nesting = link.deconstruct
    [*nesting.reverse, *ancestors(nesting.last)].lazy.filter_map { descend(it, segments, reach) }.first ||
      top(segments, reach)
  end

  def descend(entry, segments, reach)
    cuts(segments, reach).filter_map { settle(@catalog.strip(entry + segments.first(it)), segments.drop(it)) }.first
  end

  def top(segments, reach)
    cuts(segments, reach).filter_map { settle(@catalog.rooted(segments.first(it)), segments.drop(it)) }.first
  end

  def cuts(segments, reach) = segments.length.downto(reach).lazy

  def settle(path, rest)
    return unless path && known?(path)
    rest.empty? ? path : ancestral(path, rest) || path
  end

  def ancestral(path, rest)
    found = lineage(path).lazy.filter_map { descend(it, rest, rest.length) }.first
    vias[found] << path
    found
  end

  def known?(path) = @registry.exact(path) && @catalog.owned?(path)

  def ancestors(innermost) = innermost ? lineage(@catalog.strip(innermost)) : []

  def lineage(path)
    return ancestry[path] if ancestry.key?(path)
    ancestry[path] = []
    ancestry[path] = climb(path)
  end

  def ancestry = @_ancestry ||= {}

  def climb(path) = parents(path).flat_map { [it, *lineage(it)] }.uniq

  def parents(path) = @catalog.parents(path).filter_map { bind(it, it.reach) }

  def qualify(found) = (found unless found == Hashira::Coupling::ConstantRegistry::AMBIGUOUS)
end
