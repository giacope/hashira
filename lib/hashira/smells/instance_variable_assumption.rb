# frozen_string_literal: true

require "prism"

class Hashira::Smells::InstanceVariableAssumption < Hashira::Smells::Check
  SETTERS = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableTargetNode
  ].freeze

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

  def smelly? = subject.kind == :class && assumed.any?

  def assumed = @assumed ||= (read - prepared).uniq.sort

  def read = subject.owned.flat_map { Harvest.reads(it.node) }

  def prepared
    starters.flat_map { Hashira::Smells::Scope.inside(it.node) }.select { SETTERS.include?(it.class) }.map(&:name)
  end

  def starters = subject.owned.select { it.node.name == :initialize }

  def evidence = assumed.map(&:to_s)
end
