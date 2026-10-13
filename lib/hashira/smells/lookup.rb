# frozen_string_literal: true

require "prism"
require_relative "foreign"

module Hashira::Smells::Lookup
  KEYED = Hashira::Smells::Foreign::KEYED_READS

  KEYS = Hashira::Smells::Foreign::KEYS

  NEAR = [NilClass, Prism::SelfNode, Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  module_function

  def cheap?(call) = !call.block && (reader?(call) || keyed?(call)) && NEAR.include?(call.receiver.class)

  def reader?(call) = !call.arguments

  def keyed?(call) = KEYED.include?(call.name) && call.arguments.arguments.all? { KEYS.include?(it.class) }
end
