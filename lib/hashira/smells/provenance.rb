# frozen_string_literal: true

require "prism"

class Hashira::Smells::Provenance
  def initialize(inputs, writes, answers, holders)
    @inputs = inputs
    @writes = writes
    @answers = answers
    @holders = holders
  end

  def made?(node, seen = Set.new)
    case node
    when Prism::InstanceVariableReadNode, Prism::NilNode then true
    when Prism::LocalVariableReadNode then seen.add?(node.name) && local?(node.name, seen)
    else node.is_a?(Prism::CallNode) && @answers.answered?(node)
    end
  end

  def source(node) = @inputs.strict? ? sourced(node) : []

  def options(nodes) = nodes.select { @inputs.optional?(it) }.map { it.name.to_s }.uniq

  def origin(node) = @holders.origin(node).then { it.empty? ? source(node) : it }

  private

  def sourced(node)
    case node
    when Prism::LocalVariableReadNode then agreed(@writes.of(node.name).map { sourced(it.value) })
    when Prism::CallNode then @holders.sprung(node)
    else []
    end
  end

  def agreed(found) = found.all?(&:one?) ? Hashira::Smells::Sole.new(found.flatten).to_a : []

  def local?(name, seen)
    @inputs.parameter?(name) ? @inputs.handed?(name) : @writes.of(name).any? { made?(it.value, seen) }
  end
end
