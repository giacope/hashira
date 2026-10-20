# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(trees, catalog = nil)
    @trees = trees
    @catalog = catalog
  end

  def owned?(segments, owner = nil, rooted: false)
    surveyed
    return @_defined.include?(segments.join("::")) if rooted
    return true if lexical(segments, owner).any? { @_defined.include?(it) }
    !builtin?(segments.first) && @_suffixes.include?(segments.join("::"))
  end

  def owns?(node, owner = nil)
    owned?(Hashira::Analysis::Syntax.segments(node), owner, rooted: Hashira::Analysis::Syntax.rooted?(node))
  end

  def vocabulary = @_vocabulary ||= Hashira::Smells::Vocabulary.new(@trees)

  def repertoire = @_repertoire ||= Hashira::Smells::Repertoire.new(@trees)

  def values = @_values ||= Hashira::Smells::Values.new(@trees)

  def calls(name) = sent.fetch(name, [])

  def keys(segments)
    surveyed
    @_tables.fetch(segments.join("::"), [])
  end

  private

  def sent = @_sent ||= @trees.flat_map { called(it) }.group_by(&:name)

  def called(tree) = Hashira::Analysis::NodeWalk.collect(tree).grep(Prism::CallNode)

  def surveyed
    return if @_surveyed
    @_surveyed = true
    @_suffixes = Set.new
    @_defined = Set.new
    @_tables = {}
    @trees.each { survey(it) }
  end

  def survey(tree)
    Hashira::Analysis::TypeWalk.each(tree) do |node, full|
      next unless claimed?(full)
      absorb(full)
      Hashira::Analysis::Syntax.constants(node).each { record(full, it) }
    end
  end

  def record(full, constant)
    path = full + [constant.name.to_s]
    absorb(path)
    chart(path, thaw(constant.value))
  end

  def absorb(path)
    @_defined << path.join("::")
    @_suffixes.merge(suffixes(path))
  end

  def lexical(segments, owner)
    parts = owner.to_s.split("::")
    parts.size.downto(0).map { (parts.first(it) + segments).join("::") }
  end

  def builtin?(name)
    Hashira::Analysis::CORE.include?(name) || Hashira::Analysis::LIBRARIES.include?(name.to_s.downcase)
  end

  def chart(path, value)
    return unless value.is_a?(Prism::HashNode)
    keys = value.elements.map { spine(it) }
    return if keys.empty? || keys.any?(&:nil?)
    suffixes(path).each { @_tables[it] = keys }
  end

  def thaw(value)
    frozen?(value) ? value.receiver : value
  end

  def frozen?(value) = value.is_a?(Prism::CallNode) && value.name == :freeze

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
