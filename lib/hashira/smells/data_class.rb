# frozen_string_literal: true

require "prism"

class Hashira::Smells::DataClass < Hashira::Smells::Check
  MARKERS = Hashira::Analysis::TypeWalk::MARKERS

  CONSTRUCTOR = :initialize

  MINIMUM = 2

  private

  def smelly? = subject.kind == :class && unrelated? && statements.all? { plain?(it) } && fields.size >= MINIMUM

  def unrelated? = subject.nodes.none?(&:superclass) && subject.family.children(subject.subject).empty?

  def statements = @_statements ||= subject.nodes.flat_map { Hashira::Analysis::Syntax.statements(it) }.compact

  def plain?(node)
    case node
    when Prism::CallNode then !node.receiver && (Hashira::Smells::Attributes::EVERY + MARKERS).include?(node.name)
    when Prism::DefNode then !node.receiver && (node.name == CONSTRUCTOR ? stores?(node) : access?(node))
    else false
    end
  end

  def body(definition) = Hashira::Analysis::Syntax.statements(definition).compact

  def stores?(definition) = body(definition).all? { it.is_a?(Prism::InstanceVariableWriteNode) && given?(it.value) }

  def given?(value) = value.is_a?(Prism::LocalVariableReadNode) || value.is_a?(Prism::NilNode)

  def access?(definition)
    held = body(definition)
    held.one? && (held.first.is_a?(Prism::InstanceVariableReadNode) || stores?(definition))
  end

  def fields = @_fields ||= (Hashira::Smells::Attributes.declared(statements) + stored).uniq

  def stored
    statements.grep(Prism::DefNode).flat_map { body(it) }.grep(Prism::InstanceVariableWriteNode).map { it.name.to_s.delete_prefix("@") }
  end

  def detail = { site:, fields: }

  def evidence = fields
end
