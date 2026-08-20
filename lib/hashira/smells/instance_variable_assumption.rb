# frozen_string_literal: true

require "prism"

class Hashira::Smells::InstanceVariableAssumption < Hashira::Smells::Check
  MAYBES = [
    Prism::LocalVariableOrWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::ClassVariableOrWriteNode, Prism::GlobalVariableOrWriteNode,
    Prism::ConstantOrWriteNode, Prism::ConstantPathOrWriteNode,
    Prism::CallOrWriteNode, Prism::IndexOrWriteNode
  ].freeze

  module Harvest
    module_function

    def reads(node)
      return [] if MAYBES.include?(node.class)
      below = node.compact_child_nodes.flat_map { reads(it) }
      node.is_a?(Prism::InstanceVariableReadNode) ? below + [node.name] : below
    end
  end

  private

  def smelly? = subject.kind == :class && assigned && assumed.any?

  def assigned = subject.assigned

  def assumed = @_assumed ||= (read - assigned).uniq.sort.reject { cache?(it) }

  def cache?(name) = name.start_with?("@_")

  def read = subject.owned.flat_map { Harvest.reads(it.node) }

  def evidence = assumed.map(&:to_s)
end
