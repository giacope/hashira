# frozen_string_literal: true

require "prism"
require_relative "dispatch"
require_relative "rule"
require_relative "table"

class Hashira::Smells::Gated::RegistryGap < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  SENDERS = %i[send public_send __send__].freeze

  READS = %i[fetch []].freeze

  private

  def subjects(type) = dispatches(type).select(&:routed?)

  def entry(_type, dispatch)
    absent = dispatch.unanswered(family)
    finding(**dispatch.gap(absent)) unless absent.empty?
  end

  def dispatches(type)
    tables(type).map { Hashira::Smells::Gated::Dispatch.new(type:, table: it, routes: routes(type, it)) }
  end

  def tables(type)
    Hashira::Analysis::Syntax.constants(type.node).map { Hashira::Smells::Gated::Table.new(it) }.select(&:dispatch?)
  end

  def routes(type, table)
    Hashira::Smells::Scope.sweep(type.node).grep(Prism::CallNode).filter_map { read(it, table) }
  end

  def read(node, table)
    return unless sends?(node)
    given = node.arguments&.arguments&.first
    given if reads?(given, table)
  end

  def sends?(node) = sender?(node.name) && selfish?(node.receiver)

  def sender?(call) = SENDERS.include?(call)

  def reads?(node, table)
    return false unless node.is_a?(Prism::CallNode) && READS.include?(node.name)
    holder = node.receiver
    holder.is_a?(Prism::ConstantReadNode) && holder.name == table.name
  end
end
