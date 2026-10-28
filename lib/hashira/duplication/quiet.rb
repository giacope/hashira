# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Quiet
  def initialize(nodes, walks)
    @nodes = nodes
    @walks = walks
  end

  def nodes = (sinks.flat_map(&:message) + recoveries + stores).uniq

  private

  def stores = @nodes.grep(Prism::DefNode).select { storing?(it) || stub?(it) }.flat_map { @walks.nodes([it]) }

  def stub?(definition)
    statements = Hashira::Analysis::Syntax.new(definition).statements
    statements.one? && (statements.first in Prism::CallNode[receiver: nil, name: :raise | :fail])
  end

  def storing?(definition)
    definition.name == :initialize && Hashira::Analysis::Syntax.new(definition).statements.all? { stored?(it) }
  end

  def stored?(node) = (node in Prism::InstanceVariableWriteNode[value: Prism::LocalVariableReadNode])

  def recoveries = Hashira::Duplication::Recovery.of(@nodes).flat_map { @walks.nodes([it.clause]) }

  def sinks = @nodes.grep(Prism::CallNode).map { Hashira::Duplication::Sink.new(it) }.select(&:sink?)
end
