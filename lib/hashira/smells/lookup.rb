# frozen_string_literal: true

require "prism"
require_relative "foreign"

module Hashira::Smells::Lookup
  KEYED = Hashira::Smells::Foreign::KEYED_READS

  KEYS = Hashira::Smells::Foreign::KEYS

  CLOCKS = %i[now today clock_gettime].freeze

  CALENDARS = %w[Time Date DateTime].freeze

  module_function

  def cheap?(call) = !call.block && (reader?(call) || keyed?(call)) && !reaching?(call) && !clock?(call)

  def reader?(call) = !call.arguments

  def keyed?(call) = KEYED.include?(call.name) && call.arguments.arguments.all? { KEYS.include?(it.class) }

  def reaching?(call)
    held = call.receiver
    held.is_a?(Prism::CallNode) && held.receiver.is_a?(Prism::Node)
  end

  def clock?(call) = ticks?(call.name, call.receiver&.slice)

  def ticks?(name, receiver) = CLOCKS.include?(name) || (name == :current && CALENDARS.include?(receiver))
end
