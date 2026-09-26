# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(trees)
    @trees = trees
  end

  def owned?(segments) = suffixed.include?(segments.join("::"))

  def keys(segments) = tables.fetch(segments.join("::"), [])

  private

  def suffixed = @_suffixed ||= (walked.map(&:last) + constants.map(&:first)).flat_map { suffixes(it) }.to_set

  def tables = @_tables ||= constants.each_with_object({}) { |(path, value), found| chart(found, path, thaw(value)) }

  def constants = @_constants ||= walked.flat_map { |node, full| declared(node, full) }

  def declared(node, full) = Hashira::Analysis::Syntax.constants(node).map { [full + [it.name.to_s], it.value] }

  def walked = @_walked ||= @trees.flat_map { Hashira::Analysis::TypeWalk.enum_for(:each, it).to_a }

  def chart(found, path, value)
    return unless value.is_a?(Prism::HashNode)
    keys = value.elements.map { spine(it) }
    return if keys.empty? || keys.any?(&:nil?)
    suffixes(path).each { found[it] = keys }
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
