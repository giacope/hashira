# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Body
  SCHEMA = %i[
    class_node module_node statements_node arguments_node assoc_node block_node
    array_node hash_node keyword_hash_node constant_read_node constant_path_node constant_write_node
    symbol_node string_node interpolated_string_node regular_expression_node
    integer_node float_node true_node false_node nil_node block_argument_node
  ].freeze

  def initialize(nodes, setting)
    @nodes = nodes
    @setting = setting
  end

  def to_a = @nodes

  def recurs?(name) = @setting.recurs?(name)

  def identifiers = @nodes.filter_map { it.deconstruct_keys([:name])[:name] }

  def schema? = @nodes.all? { pardoned.include?(it) || directive?(it) }

  private

  def pardoned = @_pardoned ||= @setting.macros(@nodes).flat_map { Hashira::Duplication::Macro.new(it).pardoned }.to_set

  def directive?(node)
    return SCHEMA.include?(node.type) unless node.is_a?(Prism::CallNode)
    node.receiver ? constant?(node) : literals?(node.arguments)
  end

  def constant?(call) = !call.arguments && (thawed?(call) || (!call.block && fixed?(call)))

  def thawed?(call)
    passed = call.block
    passed.is_a?(Prism::BlockArgumentNode) && frozen?(passed.expression) && named?(call.receiver)
  end

  def frozen?(expression) = expression.is_a?(Prism::SymbolNode) && expression.unescaped == "freeze"

  def named?(receiver) = receiver.is_a?(Prism::ConstantReadNode) || receiver.is_a?(Prism::ConstantPathNode)

  def fixed?(call)
    held = Hashira::Duplication::Literal.new(call.receiver)
    call.name == :freeze ? held.declarative? : held.literal?
  end

  def literals?(arguments) = Hashira::Duplication::Literal.new(arguments, pardoned).literals?
end
