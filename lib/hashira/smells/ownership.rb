# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(trees)
    @trees = trees
  end

  def owned?(segments)
    surveyed
    @suffixes.include?(segments.join("::"))
  end

  def keys(segments)
    surveyed
    @tables.fetch(segments.join("::"), [])
  end

  private

  def surveyed
    return if @surveyed
    @surveyed = true
    @suffixes = Set.new
    @tables = {}
    @trees.each { survey(it) }
  end

  def survey(tree)
    Hashira::Analysis::TypeWalk.each(tree) do |node, full|
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
    @suffixes.merge(suffixes(path))
  end

  def chart(path, value)
    return unless value.is_a?(Prism::HashNode)
    keys = value.elements.map { spine(it) }
    return if keys.empty? || keys.any?(&:nil?)
    suffixes(path).each { @tables[it] = keys }
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

  def suffixes(path)
    path.each_index.map { path.drop(it).join("::") }
  end
end
