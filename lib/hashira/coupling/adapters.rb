# frozen_string_literal: true

class Hashira::Coupling::Adapters
  RECORD = %w[ActiveRecord Base].freeze

  MARKS = %i[abstract_class= primary_abstract_class].freeze

  def initialize(catalog)
    @catalog = catalog
  end

  def include?(name)
    @_names ||= classes.group_by(&:name).select { |_, group| framed?(group) }.keys.to_set
    @_names.include?(name)
  end

  private

  def framed?(group) = group.all? { !owned?(it) } && group.any? { adapter?(it) } && !concrete?(group)

  def concrete?(group) = group.any? { parent(it) == RECORD } && group.none? { marked?(it) || named?(it) }

  def named?(definition) = definition.path.last.start_with?("Application")

  def marked?(definition)
    Hashira::Analysis::Syntax.new(definition.node).statements.grep(Prism::CallNode).any? { MARKS.include?(it.name) }
  end

  def classes = @_classes ||= @catalog.select(&:klass?)

  def adapter?(definition) = heirs.any? { ends?(definition.path, it) }

  def parent(definition) = Hashira::Analysis::Syntax.new(definition.superclass).segments

  def heirs = @_heirs ||= classes.map { @catalog.strip(parent(it)) }.reject(&:empty?)

  def owned?(definition)
    segments = parent(definition)
    return !definition.superclass if segments.empty?
    candidates(definition, segments).any? { paths.include?(@catalog.strip(it)) }
  end

  def candidates(definition, segments)
    return [segments] if Hashira::Analysis::Syntax.new(definition.superclass).rooted?
    [*definition.scope[...-1].reverse.map { it + segments }, segments]
  end

  def paths = @_paths ||= @catalog.to_set(&:path)

  def ends?(path, segments) = path.last(segments.size) == segments
end
