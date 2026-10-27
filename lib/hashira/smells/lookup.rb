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

  SELVES = [NilClass, Prism::SelfNode].freeze

  def initialize(call, home)
    @call = call
    @home = home
  end

  def cheap? = !@call.block && (reader? || keyed?) && near?(@call.receiver)

  private

  def near?(receiver) = NEAR.include?(receiver.class) || (keyed? && attribute?(receiver))

  def attribute?(read) = read.is_a?(Prism::CallNode) && own?(read) && readers.include?(read.name.to_s)

  def own?(read) = !read.arguments && SELVES.include?(read.receiver.class)

  def readers
    Hashira::Smells::Attributes.new(Hashira::Smells::Scope.new(@home).sweep).declared(Hashira::Smells::Attributes::READERS)
  end

  def reader? = !@call.arguments

  def keyed? = KEYED.include?(@call.name) && @call.arguments.arguments.all? { KEYS.include?(it.class) }
end
