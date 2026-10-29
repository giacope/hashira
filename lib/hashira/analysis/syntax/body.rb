# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax::Body
  CLASS_LEVEL = :ClassMethods

  private_constant :CLASS_LEVEL

  def initialize(node)
    @node = node
  end

  def to_a
    body = @node.body
    body.is_a?(Prism::StatementsNode) ? body.body : [body]
  end

  def direct = to_a.grep(Prism::DefNode)

  def constants = to_a.grep(Prism::ConstantWriteNode)

  def calls(name) = to_a.grep(Prism::CallNode).select { it.name == name && it.receiver.nil? && it.arguments }

  def class_level? = @node.is_a?(Prism::ModuleNode) && @node.name == CLASS_LEVEL
end
