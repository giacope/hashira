# frozen_string_literal: true

class Hashira::Coupling::Adapters
  def initialize(catalog)
    @catalog = catalog
  end

  def include?(name)
    @_names ||= classes.group_by(&:name).select { |_, group| framed?(group) }.keys.to_set
    @_names.include?(name)
  end

  private

  def framed?(group) = group.all? { !owned?(it) } && group.any? { adapter?(it) }

  def classes = @_classes ||= @catalog.select(&:klass?)

  def adapter?(definition) = heirs.any? { ends?(definition.path, it) }

  def parent(definition) = Hashira::Analysis::Syntax.new(definition.superclass).segments

  def heirs = @_heirs ||= classes.map { parent(it) }.reject(&:empty?)

  def owned?(definition)
    segments = parent(definition)
    return !definition.superclass if segments.empty?
    candidates(definition, segments).any? { paths.include?(it) }
  end

  def candidates(definition, segments)
    return [segments] if Hashira::Analysis::Syntax.new(definition.superclass).rooted?
    [*definition.scope[...-1].reverse.map { it + segments }, segments]
  end

  def paths = @_paths ||= @catalog.to_set(&:path)

  def ends?(path, segments) = path.last(segments.size) == segments
end
