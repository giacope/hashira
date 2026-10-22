# frozen_string_literal: true

require "prism"

class Hashira::Smells::Vocabulary
  HIDDEN = %i[private module_function].freeze

  WORD = /\A[[:alpha:]_]/

  def initialize(trees)
    @trees = trees
  end

  def speaks?(message) = WORD.match?(message) && !Hashira::Analysis::UNIVERSAL.include?(message) && spoken?(message)

  private

  def spoken?(message)
    @_words ||= @trees.each_with_object(Set.new) { |tree, found| gather(tree, found) } - concealed
    @_words.include?(stem(message))
  end

  def concealed
    types = @trees.flat_map { Hashira::Analysis::TypeWalk.new(it).to_enum(:walk).map { |node, *| node } }
    sections = types.flat_map { Hashira::Analysis::TypeWalk.new(it).sections }
    secret, open = sections.partition { |_, section| HIDDEN.include?(section) }
    names(secret) - names(open)
  end

  def names(entries) = entries.to_set { |definition, _| stem(definition.name) }

  def gather(node, found)
    found.merge(declared(node).map { stem(it) })
    node.compact_child_nodes.each { gather(it, found) } unless node.is_a?(Prism::DefNode)
  end

  def declared(node)
    return [node.name] if node.is_a?(Prism::DefNode)
    offered =
      case node
      when Prism::AliasMethodNode then [node.new_name]
      when Prism::CallNode then node.arguments&.arguments.to_a
      else []
      end
    offered.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }
  end

  def stem(name) = name.to_s.delete_suffix("=")
end
