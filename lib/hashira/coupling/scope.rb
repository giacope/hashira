# frozen_string_literal: true

class Hashira::Coupling::Scope
  CORE = Object.constants.select { Object.const_source_location(it) == [] }.to_set(&:to_s).freeze

  def initialize(registry, catalog, placement)
    @registry = registry
    @catalog = catalog
    @placement = placement
  end

  def resolve(segments, nesting)
    return if @placement.skip?(segments)
    scoped = nesting.reverse_each.filter_map { descend(it, segments) }.first
    scoped ? qualify(scoped) : outward(@catalog.strip(segments))
  end

  def pinpoint(segments)
    return if @placement.skip?(segments)
    qualify(descend([], segments))
  end

  private

  def outward(path) = CORE.include?(path.first) ? @registry.rooted(path) : @registry.package(path)

  def descend(entry, segments)
    segments.length.downto(1).filter_map { @registry.exact(@catalog.strip(entry + segments.first(it))) }.first
  end

  def qualify(found) = (found unless found == Hashira::Coupling::ConstantRegistry::AMBIGUOUS)
end
