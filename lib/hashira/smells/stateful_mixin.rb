# frozen_string_literal: true

require "prism"

class Hashira::Smells::StatefulMixin < Hashira::Smells::Check
  FIELDS = %i[
    attr_reader attr_writer attr_accessor class_attribute attribute store_accessor serialize
    belongs_to has_one has_many has_and_belongs_to_many
  ].freeze

  HOOKS = /\A(?:(?:before|after|around)_\w+|validates?(?:_\w+)?)\z/

  KEPT = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  INCLUDED = :included

  SELVES = Hashira::Smells::Origin::SELVES

  private

  def smelly? = mixin? && lent.any? && !singular? && uses.any? && subject.legible?

  def mixin? = subject.kind == :module && subject.claimed? && subject.nodes.any?(Prism::ModuleNode)

  def lent = @_lent ||= subject.owned.reject(&:mixin?)

  def singular? = statements.any? { it.is_a?(Prism::CallNode) && extends_self?(it) }

  def extends_self?(call) = call.name == :extend && Array(call.arguments&.arguments).any?(Prism::SelfNode)

  def statements = @_statements ||= subject.statements

  def uses = @_uses ||= grouped.map { |name, seen| tally(name, lines(seen)) }

  def grouped = (read + kept + installed).group_by(&:first).sort_by { |_, seen| lines(seen).min }

  def lines(seen) = seen.map(&:last).uniq.sort

  def read
    assigned = Array(subject.assigned)
    lent.flat_map { harvest(it.node) }.reject { |name, _| assigned.include?(name) || cache?(name) }
      .map { |name, line| ["reads #{name}", line] }
  end

  def harvest(definition)
    Hashira::Smells::Scope.new(definition).inside.grep(Prism::InstanceVariableReadNode).map { [it.name, line(it)] }
  end

  def kept
    lent.flat_map { Hashira::Smells::Scope.new(it.node).inside.select { KEPT.include?(it.class) } }
      .reject { cache?(it.name) }.map { ["keeps #{it.name} in its host", line(it)] }
  end

  def cache?(name) = name.start_with?("@_")

  def installed = hooked.select { installs?(it) }.map { ["installs #{it.name}", line(it)] }

  def hooked = (subject.nodes + included).flat_map { Hashira::Smells::Scope.new(it).inside }

  def included = @_included ||= statements.grep(Prism::DefNode).select { it.name == INCLUDED && it.receiver }

  def installs?(node)
    node.is_a?(Prism::CallNode) && host?(node.receiver) && (FIELDS.include?(node.name) || HOOKS.match?(node.name.to_s))
  end

  def host?(receiver) = SELVES.include?(receiver.class) || based?(receiver)

  def based?(receiver) = receiver.is_a?(Prism::LocalVariableReadNode) && bases.include?(receiver.name)

  def bases = @_bases ||= included.flat_map { Hashira::Smells::Parameters.new(it).names }

  def line(node) = node.location.start_line

  def detail = { site:, uses: uses.size }

  def evidence = uses
end
