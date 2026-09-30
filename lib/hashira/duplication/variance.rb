# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Variance
  VALUED = %i[integer_node float_node].freeze
  FIELDS = %i[name unescaped binary_operator].freeze
  NAMED = %i[call_node constant_read_node constant_path_node
    local_variable_read_node local_variable_write_node
    instance_variable_read_node instance_variable_write_node].freeze
  CATEGORIES = {
    literal: %i[integer_node float_node string_node symbol_node regular_expression_node x_string_node],
    constant: %i[constant_read_node constant_path_node constant_write_node constant_or_write_node],
    renamed: %i[def_node]
  }.freeze

  RELAYS = %i[super_node forwarding_super_node].freeze

  def initialize(canonical, other)
    @canonical = canonical
    @other = other
  end

  def kinds
    return [:structure] if @canonical.types != @other.types
    differing.map { |left, right| category(left, right) }.uniq
  end

  def structural?
    return false unless @canonical.types == @other.types
    named.any? && named.all? { |left, right| left.name != right.name }
  end

  private

  def pairs = @canonical.nodes.zip(@other.nodes)

  def named = @_named ||= pairs.select { |left, _| NAMED.include?(left.type) && !inner?(left) }

  def inner?(node) = nested.any? { it.equal?(node) }

  def nested = @_nested ||= @canonical.nodes.grep(Prism::ConstantPathNode).filter_map(&:parent)

  def differing = pairs.reject { |left, right| signature(left) == signature(right) }

  def category(left, right)
    return :structure if guarded?(left) != guarded?(right)
    type = left.type
    return :mixed if type == :def_node && relayed?
    CATEGORIES.keys.find { CATEGORIES[it].include?(type) } || :message
  end

  def relayed? = @canonical.types.any? { RELAYS.include?(it) }

  def signature(node) = [*node.deconstruct_keys(FIELDS).values_at(*FIELDS), value(node), guarded?(node)]

  def value(node) = (node.value if VALUED.include?(node.type))

  def guarded?(node) = node.is_a?(Prism::CallNode) && node.safe_navigation?
end
