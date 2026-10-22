# frozen_string_literal: true

require "prism"
require_relative "foreign"

class Hashira::Smells::Lookup
  KEYED = Hashira::Smells::Foreign::KEYED_READS

  KEYS = (Hashira::Smells::Foreign::KEYS + [Prism::IntegerNode]).freeze

  NEAR = [
    NilClass, Prism::SelfNode, Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode,
    Prism::InstanceVariableReadNode
  ].freeze

  def initialize(call)
    @call = call
  end

  def cheap? = !@call.block && (reader? || keyed?) && NEAR.include?(@call.receiver.class)

  private

  def reader? = !@call.arguments

  def keyed? = KEYED.include?(@call.name) && @call.arguments.arguments.all? { KEYS.include?(it.class) }
end
