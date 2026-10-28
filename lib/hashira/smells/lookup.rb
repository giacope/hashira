# frozen_string_literal: true

require "prism"
require_relative "foreign"

class Hashira::Smells::Lookup
  KEYED = %i[[] fetch values_at dig key?].freeze

  NEAR = [
    NilClass, Prism::SelfNode, Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode,
    Prism::InstanceVariableReadNode
  ].freeze

  def initialize(call, readers)
    @call = call
    @readers = readers
  end

  def cheap? = !@call.block && (reader? || keyed?) && near?(@call.receiver)

  private

  def near?(receiver) = NEAR.include?(receiver.class) || @readers.reads?(receiver)

  def reader? = !@call.arguments

  def keyed? = KEYED.include?(@call.name) && @call.arguments.arguments.all? { key?(it) }

  def key?(node) = Hashira::Analysis::Syntax.new(node).word? || node.is_a?(Prism::IntegerNode)
end
