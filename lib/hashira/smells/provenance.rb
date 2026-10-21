# frozen_string_literal: true

require "prism"

class Hashira::Smells::Provenance
  HIDDEN = %i[private protected].freeze

  def initialize(subject, foreign)
    @subject = subject
    @foreign = foreign
  end

  def made?(node, seen = Set.new)
    case node
    when Prism::InstanceVariableReadNode, Prism::NilNode then true
    when Prism::LocalVariableReadNode then seen.add?(node.name) && local?(node.name, seen)
    else node.is_a?(Prism::CallNode) && answered?(node)
    end
  end

  private

  def local?(name, seen) = argument?(name) ? handed?(name) : @foreign.writes(name).any? { made?(it.value, seen) }

  def argument?(name) = @subject.parameters.include?(name)

  def handed?(_name) = HIDDEN.include?(@subject.section)

  def answered?(call)
    receiver = call.receiver
    return own?(call.name) if receiver.nil? || receiver.is_a?(Prism::SelfNode)
    return @subject.ownership.owns?(receiver, @subject.owner) if constant?(receiver)
    receiver.is_a?(Prism::LocalVariableReadNode) && (@foreign.built?(receiver.name) || typed?(receiver.name, call.name))
  end

  def constant?(node) = node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)

  def own?(name) = answers.include?(name.to_s.delete_suffix("=")) || @subject.neighbors.include?(name) || hosted?(name)

  def hosted?(name) = @subject.host == :module && @subject.ownership.vocabulary.speaks?(name)

  def answers = @_answers ||= @subject.ownership.repertoire.of(@subject.owner.split("::"))

  def typed?(local, message)
    holder = Hashira::Smells::Refs::Local.new(local, @subject.node)
    @foreign.kinds(holder).any? { @subject.ownership.repertoire.of(it).include?(message.to_s.delete_suffix("=")) }
  end
end
