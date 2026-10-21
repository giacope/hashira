# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(trees, catalog = nil)
    @trees = trees
    @catalog = catalog
  end

  def owned?(segments, owner = nil, rooted: false) = !place(segments, owner, rooted:).nil?

  def place(segments, owner, rooted: false) = (among(defined, segments, owner, rooted) unless segments.empty?)

  def owns?(node, owner = nil)
    owned?(Hashira::Analysis::Syntax.segments(node), owner, rooted: Hashira::Analysis::Syntax.rooted?(node))
  end

  def vocabulary = @_vocabulary ||= Hashira::Smells::Vocabulary.new(@trees)

  def repertoire = @_repertoire ||= Hashira::Smells::Repertoire.new(@trees)

  def values = @_values ||= Hashira::Smells::Values.new(@trees)

  def callers = @_callers ||= Hashira::Smells::Callers.new(@trees, self)

  def resolve(segments, owner, rooted:) = among(written, segments, owner, rooted)

  def keys(segments)
    surveyed
    @_tables.fetch(segments.join("::"), [])
  end

  private

  def among(known, segments, owner, rooted)
    (rooted ? [segments.join("::")] : lexical(segments, owner)).find { known.include?(it) }
  end

  def defined
    surveyed
    @_defined
  end

  def written
    surveyed
    @_written
  end

  def surveyed
    return if @_surveyed
    @_surveyed = true
    @_defined = Set.new
    @_written = Set.new
    @_tables = {}
    @trees.each { survey(it) }
  end

  def survey(tree)
    Hashira::Analysis::TypeWalk.each(tree) do |node, full|
      @_written << full.join("::")
      next unless claimed?(full)
      absorb(full)
      Hashira::Analysis::Syntax.constants(node).each { record(full, it) }
    end
  end

  def record(full, constant)
    path = full + [constant.name.to_s]
    absorb(path)
    chart(path, Hashira::Analysis::Syntax.thaw(constant.value))
  end

  def absorb(path) = @_defined << path.join("::")

  def lexical(segments, owner)
    parts = owner.to_s.split("::")
    parts.size.downto(0).map { (parts.first(it) + segments).join("::") }
  end

  def chart(path, value)
    return unless value.is_a?(Prism::HashNode)
    keys = value.elements.map { spine(it) }
    return if keys.empty? || keys.any?(&:nil?)
    suffixes(path).each { @_tables[it] = keys }
  end

  def spine(element)
    return unless element.is_a?(Prism::AssocNode)
    segments = Hashira::Analysis::Syntax.segments(element.key)
    segments unless segments.empty?
  end

  def claimed?(full) = !@catalog || @catalog.claimed?(full)

  def suffixes(path)
    path.each_index.map { path.drop(it).join("::") }
  end
end
