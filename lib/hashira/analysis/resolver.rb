# frozen_string_literal: true

class Hashira::Analysis::Resolver
  def initialize(registry, catalog, placement)
    @registry = registry
    @catalog = catalog
    @placement = placement
  end

  def resolve(segments, nesting)
    return if @placement.skip?(segments)
    scoped = nesting.reverse_each.filter_map { descend(it, segments) }.first
    scoped ? qualify(scoped) : @registry.package(@catalog.strip(segments))
  end

  def pinpoint(segments)
    return if @placement.skip?(segments)
    qualify(descend([], segments))
  end

  private

  def descend(entry, segments)
    segments.length.downto(1).filter_map { @registry.exact(@catalog.strip(entry + segments.first(it))) }.first
  end

  def qualify(found) = (found unless found == Hashira::Analysis::ConstantRegistry::AMBIGUOUS)
end
