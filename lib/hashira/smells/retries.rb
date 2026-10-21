# frozen_string_literal: true

require "prism"

class Hashira::Smells::Retries
  CONDITIONALS = [Prism::IfNode, Prism::UnlessNode].freeze

  def initialize(method)
    @method = method
  end

  def retry?(first, second)
    tests = inside(@method).select { CONDITIONALS.include?(it.class) }
    writes.any? do |write|
      within?(write.value, first) && tests.any? { asks?(it.predicate, write.name) && fallback?(it, write, second) }
    end
  end

  private

  def writes = @_writes ||= inside(@method).grep(Prism::LocalVariableWriteNode)

  def asks?(predicate, name) = [predicate, *inside(predicate)].any? { read?(it, name) }

  def fallback?(test, write, call)
    values = arms(test).grep(Prism::StatementsNode).map { it.body.last }
    values.any? { it.slice == write.value.slice && within?(it, call) } && values.any? { read?(it, write.name) }
  end

  def arms(test) = (test.compact_child_nodes - [test.predicate]).flat_map { opened(it) }

  def opened(arm) = arm.is_a?(Prism::ElseNode) ? arm.compact_child_nodes : [arm]

  def read?(node, name) = node.is_a?(Prism::LocalVariableReadNode) && node.name == name

  def within?(outer, node) = outer.equal?(node) || inside(outer).any? { it.equal?(node) }

  def inside(node) = Hashira::Smells::Scope.inside(node)
end
