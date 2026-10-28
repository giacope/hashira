# frozen_string_literal: true

require "prism"

class Hashira::Smells::Columns
  ASKED = %i[read_attribute [] increment increment! decrement decrement! toggle toggle!].freeze

  TOLD = %i[write_attribute update_attribute update_column []=].freeze

  FILLED = %i[update update! update_columns assign_attributes attributes=].freeze

  COMPOUND = [Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode].freeze

  HASHES = [Prism::KeywordHashNode, Prism::HashNode].freeze

  WORD = /\A[a-z_][a-zA-Z0-9_]*\z/

  def initialize(nodes)
    @nodes = nodes
  end

  def read = inward.flat_map { asked(it) }

  def touched = read + inward.grep(Prism::CallNode).flat_map { told(it) }

  private

  def inward = @_inward ||= @nodes.select { inward?(it) }

  def inward?(node) = (COMPOUND.include?(node.class) || node.is_a?(Prism::CallNode)) && selfish?(node.receiver)

  def selfish?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def asked(node)
    return [node.read_name] if COMPOUND.include?(node.class)
    return [node.name] if plain?(node)
    ASKED.include?(node.name) ? first(node) : []
  end

  def plain?(call) = !call.arguments && !call.block && WORD.match?(call.name)

  def told(call)
    name = call.name
    return [name.to_s.delete_suffix("=").to_sym] if call.attribute_write? && name != :[]=
    return first(call) if TOLD.include?(name)
    FILLED.include?(name) ? keys(call) : []
  end

  def first(call) = words(arguments(call).first)

  def keys(call)
    arguments(call).select { HASHES.include?(it.class) }.flat_map(&:elements).grep(Prism::AssocNode).flat_map { words(it.key) }
  end

  def arguments(call) = Array(call.arguments&.arguments)

  def words(node) = Hashira::Analysis::Syntax.new(node).words
end
