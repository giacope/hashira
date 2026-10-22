# frozen_string_literal: true

require "prism"
require_relative "bindings"
require_relative "scope"

class Hashira::Smells::Course
  LOOPS = Hashira::Smells::Bindings::LOOPS

  WRITES = [Prism::LocalVariableWriteNode, Prism::InstanceVariableWriteNode].freeze

  Stretch =
    Data.define(:first, :last, :held) do
      def ends = [first, last]

      def leaves?(exit) = covers?(exit, first) && !covers?(exit, last)

      def spans?(node) = first.location.end_offset <= node.location.end_offset && before?(node)

      def before?(node) = node.location.end_offset < last.location.end_offset && !covers?(last, node)

      def covers?(outer, node) = Hashira::Smells::Scope.new(outer).covers?(node)

      def aims?(call) = held.include?(call.receiver&.slice)

      def hands?(call) = handed(call).any? { held.include?(it.slice) }

      def handed(call) = Array(call.arguments&.arguments).flat_map { values(it) }.compact

      def values(argument) = argument.is_a?(Prism::KeywordHashNode) ? argument.elements.map(&:value) : [argument]
    end

  def initialize(definition, calls, discards, branches)
    @definition = definition
    @calls = calls
    @discards = discards
    @branches = branches
  end

  def parted?(pair)
    first, last = pair
    stretch = Stretch.new(first:, last:, held: receivers(first))
    left?(stretch) || disturbed?(stretch)
  end

  private

  def receivers(call)
    [call, *Hashira::Smells::Scope.new(call).inside].grep(Prism::CallNode).filter_map { it.receiver&.slice }
  end

  def left?(stretch)
    last = stretch.last
    !ensured?(last) && returns.any? { stretch.leaves?(it) && !looped?(it, last) }
  end

  def looped?(exit, node) = sorted.values_at(*LOOPS).compact.flatten.any? { covers?(it, exit) && covers?(it, node) }

  def ensured?(node) = sorted.fetch(Prism::EnsureNode, []).any? { covers?(it, node) }

  def covers?(outer, node) = Hashira::Smells::Scope.new(outer).covers?(node)

  def nodes = @_nodes ||= Hashira::Smells::Scope.new(@definition).inside

  def sorted = @_sorted ||= nodes.group_by(&:class)

  def returns = sorted.fetch(Prism::ReturnNode, []) + sorted.fetch(Prism::AndNode, []).select { jump?(it.right) }

  def jump?(node) = node.is_a?(Prism::ReturnNode) || Hashira::Smells::Exits.new(node).raise?

  def disturbed?(stretch)
    disturbs?(stretch, commands) { stretch.aims?(it) } || disturbs?(stretch, steps) { stretch.hands?(it) }
  end

  def disturbs?(stretch, calls) = calls.any? { stretch.spans?(it) && meets?(it, stretch) && yield(it) }

  def commands = @_commands ||= @calls.select { @discards.include?(it) }

  def steps
    @_steps ||= commands + nodes.grep(Prism::StatementsNode).flat_map(&:body).select { WRITES.include?(it.class) }
      .map(&:value).grep(Prism::CallNode)
  end

  def meets?(call, stretch) = stretch.ends.all? { @branches.together?([call, it]) }
end
