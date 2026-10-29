# frozen_string_literal: true

class Hashira::Coupling::Adapters
  RECORD = %w[ActiveRecord Base].freeze

  MARKS = %i[abstract_class= primary_abstract_class].freeze

  def initialize(catalog)
    @catalog = catalog
  end

  def include?(name)
    @_names ||= classes.group_by { it.to_a.first }.select { |_, group| framed?(group) }.keys.to_set
    @_names.include?(name)
  end

  private

  def framed?(group)
    group.all? { !owned?(it.kin, it.site) } && group.any? { adapter?(it.to_a) } && !concrete?(group)
  end

  def concrete?(group)
    group.any? { parent(it.kin) == RECORD } && group.none? { marked?(it.form) || named?(it.to_a) }
  end

  def named?(path) = path.last.start_with?("Application")

  def marked?(form) = form.to_a.grep(Prism::CallNode).any? { MARKS.include?(it.name) }

  def classes = @_classes ||= @catalog.select { it.form.klass? }

  def adapter?(path) = heirs.any? { ends?(path, it) }

  def parent(kin) = superclass(kin).segments

  def superclass(kin) = Hashira::Analysis::Syntax.new(kin.parent.first)

  def heirs = @_heirs ||= classes.map { @catalog.strip(parent(it.kin)) }.reject(&:empty?)

  def owned?(kin, site)
    segments = parent(kin)
    return kin.parent.empty? if segments.empty?
    candidates(kin, site, segments).any? { paths.include?(@catalog.strip(it)) }
  end

  def candidates(kin, site, segments) = superclass(kin).rooted? ? [segments] : site.nestings(segments)

  def paths = @_paths ||= @catalog.to_set(&:to_a)

  def ends?(path, segments) = path.last(segments.size) == segments
end
