# frozen_string_literal: true

require "prism"

class Hashira::Smells::AssumedState < Hashira::Smells::Check
  MAYBES = [
    Prism::LocalVariableOrWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::ClassVariableOrWriteNode, Prism::GlobalVariableOrWriteNode,
    Prism::ConstantOrWriteNode, Prism::ConstantPathOrWriteNode,
    Prism::CallOrWriteNode, Prism::IndexOrWriteNode
  ].freeze

  Harvest =
    Data.define(:node) do
      def reads
        return [] if MAYBES.include?(node.class)
        below = node.compact_child_nodes.grep_v(Prism::DefNode).flat_map { Harvest.new(it).reads }
        node.is_a?(Prism::InstanceVariableReadNode) ? below + [node.name] : below
      end
    end

  private

  def smelly? = subject.kind == :class && subject.claimed? && assigned && assumed.any? && legible?

  def legible? = subject.sweep.none? { Hashira::Smells::Opaque.new([it]).any? }

  def assigned = subject.assigned

  def assumed = @_assumed ||= (read - assigned).uniq.sort.reject { cache?(it) || computed?(it) }

  def cache?(name) = name.start_with?("@_")

  def computed?(name) = assigned.grep(String).any? { name.start_with?(it) }

  def read = subject.owned.flat_map { Harvest.new(it.node).reads }

  def installed = assumed & subject.heirs

  def detail = { site:, installed: installed.map(&:to_s), unassigned: (assumed - installed).map(&:to_s) }

  def evidence = assumed.map(&:to_s)
end
