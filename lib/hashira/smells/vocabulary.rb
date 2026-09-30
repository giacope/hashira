# frozen_string_literal: true

require "prism"

class Hashira::Smells::Vocabulary
  UNIVERSAL = (BasicObject.instance_methods + Kernel.instance_methods).to_set.freeze

  HIDDEN = %i[private module_function].freeze

  WORD = /\A[[:alpha:]_]/

  def initialize(trees)
    @trees = trees
  end

  def speaks?(message) = WORD.match?(message) && !UNIVERSAL.include?(message) && words.include?(stem(message))

  private

  def words = @_words ||= spoken - concealed

  def spoken = @trees.each_with_object(Set.new) { |tree, found| gather(tree, found) }

  def concealed
    secret, open = entries.partition { |_, section| HIDDEN.include?(section) }
    names(secret) - names(open)
  end

  def names(entries) = entries.to_set { |definition, _| stem(definition.name) }

  def entries = @trees.flat_map { |tree| types(tree).flat_map { Hashira::Smells::Visibility.new(it).entries } }

  def types(tree)
    found = []
    Hashira::Analysis::TypeWalk.each(tree) { |node, _| found << node }
    found
  end

  def gather(node, found)
    found.merge(declared(node).map { stem(it) })
    node.compact_child_nodes.each { gather(it, found) } unless node.is_a?(Prism::DefNode)
  end

  def declared(node) = node.is_a?(Prism::DefNode) ? [node.name] : offered(node).grep(Prism::SymbolNode).map(&:unescaped)

  def offered(node)
    case node
    when Prism::AliasMethodNode then [node.new_name]
    when Prism::CallNode then node.arguments&.arguments.to_a
    else []
    end
  end

  def stem(name) = name.to_s.delete_suffix("=")
end
