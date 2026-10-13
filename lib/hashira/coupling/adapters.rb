# frozen_string_literal: true

class Hashira::Coupling::Adapters
  def initialize(catalog)
    @catalog = catalog
  end

  def include?(name) = names.include?(name)

  private

  def names = @_names ||= classes.group_by(&:name).select { |_, group| framed?(group) }.keys.to_set

  def framed?(group) = group.all? { !owned?(parent(it)) } && group.any? { adapter?(it) }

  def classes = @_classes ||= @catalog.select(&:klass?)

  def adapter?(definition) = heirs.any? { ends?(definition.path, it) }

  def parent(definition) = Hashira::Analysis::Syntax.segments(definition.superclass)

  def heirs = @_heirs ||= classes.map { parent(it) }.reject(&:empty?)

  def owned?(segments) = segments.empty? || paths.any? { ends?(it, segments) }

  def paths = @_paths ||= @catalog.map(&:path)

  def ends?(path, segments) = path.last(segments.size) == segments
end
