# frozen_string_literal: true

class Hashira::Duplication::Variance
  LITERALS = %i[integer_node float_node string_node symbol_node].freeze
  VALUED = %i[integer_node float_node].freeze
  NAMED = %i[call_node constant_read_node constant_path_node
    local_variable_read_node local_variable_write_node
    instance_variable_read_node instance_variable_write_node].freeze
  CONSTANTS = %i[constant_read_node constant_path_node].freeze

  def initialize(canonical, other)
    @canonical = canonical
    @other = other
  end

  def kinds
    return [:structure] if @canonical.types != @other.types
    differing.map { |node| category(node) }.uniq
  end

  def structural?
    return false unless @canonical.types == @other.types
    named.any? && named.all? { |left, right| left.name != right.name }
  end

  private

  def pairs = @canonical.nodes.zip(@other.nodes)

  def named = @_named ||= pairs.select { |left, _| NAMED.include?(left.type) }

  def differing = pairs.select { |pair| varies?(*pair) }.map(&:first)

  def varies?(left, right) = signature(left) != signature(right)

  def category(node)
    type = node.type
    return :literal if LITERALS.include?(type)
    CONSTANTS.include?(type) ? :constant : :message
  end

  def signature(node)
    LITERALS.include?(node.type) ? literal(node) : label(node)
  end

  def label(node) = (node.name if NAMED.include?(node.type))

  def literal(node) = VALUED.include?(node.type) ? node.value : node.unescaped
end
