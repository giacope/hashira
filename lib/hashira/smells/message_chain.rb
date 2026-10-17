# frozen_string_literal: true

require "prism"

class Hashira::Smells::MessageChain < Hashira::Smells::Check
  private

  def smelly? = chains.any?

  def ownership = subject.ownership

  def repertoire = @_repertoire ||= ownership.repertoire

  def values = @_values ||= ownership.values

  def chains
    @_chains ||=
      begin
        found = Hashira::Smells::Scope.inside(subject.node).grep(Prism::CallNode).select { chained?(it) }
        found.reject { |call| found.any? { it.receiver.equal?(call) } }
      end
  end

  def chained?(call)
    hop = call.receiver
    return false unless hop.is_a?(Prism::CallNode) && !inward?(hop.receiver) && !hop.block
    far = type(hop)
    far && answers?(far, call.name) && !values.include?(far)
  end

  def answers?(type, message)
    !Hashira::Analysis::UNIVERSAL.include?(message) && repertoire.of([type]).include?(message.to_s.delete_suffix("="))
  end

  def type(node)
    case node
    when Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode then named(node.name)
    when Prism::CallNode then step(node) unless node.arguments
    end
  end

  def step(call)
    message = call.name
    return named(message) if inward?(call.receiver)
    near = type(call.receiver)
    far = named(message)
    far if near && near != far && answers?(near, message)
  end

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def named(name)
    Hashira::Smells::Naming.types(name.to_s.delete_prefix("@")).map(&:first).find { ownership.owned?([it]) }
  end

  def path(node)
    node.is_a?(Prism::CallNode) && !inward?(node.receiver) ? path(node.receiver) + [type(node)] : [type(node)]
  end

  def detail = { site:, through: path(chains.first.receiver).first(2) }

  def evidence
    chains.map { "#{it.slice.lines.first.strip} (line #{it.location.start_line}: #{path(it.receiver).join(" → ")})" }
  end
end
