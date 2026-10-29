# frozen_string_literal: true

require "prism"
require_relative "origin"

class Hashira::Smells::Readers
  def initialize(method)
    @method = method
  end

  def reads?(node) = node.is_a?(Prism::CallNode) && plain?(node) && names.include?(node.name.to_s)

  private

  def plain?(call) = !call.arguments && !call.block && Hashira::Smells::Origin.new(call.receiver).self?

  def names
    return @_names if @_names
    swept = homes.flat_map { Hashira::Smells::Scope.new(it).sweep }
    @_names = Hashira::Smells::Attributes.new(swept).readers.to_set
  end

  def homes
    ancestry = @method.ownership.ancestry
    [@method.home, *ancestry.up(@method.owner).flat_map { ancestry.openings(it) }]
  end
end
