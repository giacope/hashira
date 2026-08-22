# frozen_string_literal: true

require "prism"
require_relative "dispatch"
require_relative "rule"
require_relative "table"

class Hashira::Smells::Gated::RegistryGap < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  SENDERS = %i[send public_send __send__].freeze

  READS = %i[fetch []].freeze

  def list = family.types.flat_map { gaps(it) }

  private

  def gaps(type)
    return [] unless family.visible?(type)
    dispatches(type).select(&:routed?).filter_map { gap(it) }
  end

  def dispatches(type)
    tables(type).map { Hashira::Smells::Gated::Dispatch.new(type:, table: it, routes: routes(type, it)) }
  end

  def tables(type)
    Hashira::Analysis::Syntax.constants(type.node).map { Hashira::Smells::Gated::Table.new(it) }.select(&:dispatch?)
  end

  def gap(dispatch)
    absent = dispatch.entries.reject { family.answers?(dispatch.type, it.last) }
    entry(dispatch, absent) unless absent.empty?
  end

  def entry(dispatch, absent) = finding(**dispatch.gap(absent))

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

  def selfish?(receiver) = !receiver || receiver.is_a?(Prism::SelfNode)

  def reads?(node, table)
    return false unless node.is_a?(Prism::CallNode) && READS.include?(node.name)
    holder = node.receiver
    holder.is_a?(Prism::ConstantReadNode) && holder.name == table.name
  end
end
