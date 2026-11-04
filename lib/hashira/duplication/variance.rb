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

  WORD = /\A[[:alpha:]_]/

  def initialize(canonical, other)
    @canonical = canonical
    @other = other
  end

  def kinds
    return [:structure] if @canonical.shape.to_a != @other.shape.to_a
    differing.map { |left, right| category(left, right) }.uniq
  end

  def drifts = differing.map(&:first)

  def structural?
    return false unless @canonical.shape.to_a == @other.shape.to_a
    named.any? && named.all? { |left, right| left.name != right.name }
  end

  private

  def pairs = @_pairs ||= bodies.map(&:to_a).reduce(:zip)

  def bodies = @_bodies ||= [@canonical.body, @other.body]

  def named = @_named ||= pairs.select { |left, _| spoken?(left) && !inner?(left) && !recurring?(left) }

  def spoken?(node) = NAMED.include?(node.type) && worded?(node)

  def worded?(node) = WORD.match?(node.name.to_s)

  def recurring?(node) = bodies.any? { it.recurs?(node.name) }

  def inner?(node) = nested.any? { it.equal?(node) }

  def nested = @_nested ||= bodies.first.to_a.grep(Prism::ConstantPathNode).filter_map(&:parent)

  def differing = pairs.reject { |left, right| signature(left) == signature(right) }

  def category(left, right)
    return :nil_guard if guarded?(left) != guarded?(right)
    type = left.type
    return :mixed if type == :def_node && relayed?
    CATEGORIES.keys.find { CATEGORIES[it].include?(type) } || :message
  end

  def relayed? = @canonical.shape.to_a.any? { RELAYS.include?(it) }

  def signature(node) = [*node.deconstruct_keys(FIELDS).values_at(*FIELDS), value(node), guarded?(node)]

  def value(node) = (node.value if VALUED.include?(node.type))

  def guarded?(node) = node.is_a?(Prism::CallNode) && node.safe_navigation?
end
