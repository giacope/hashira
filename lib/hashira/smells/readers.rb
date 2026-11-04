# frozen_string_literal: true

require "prism"
require_relative "origin"

class Hashira::Smells::Readers
  def initialize(method, ties)
    @method = method
    @ties = ties
  end

  def reads?(node) = node.is_a?(Prism::CallNode) && plain?(node) && names.include?(node.name.to_s)

  private

  def plain?(call) = !call.arguments && !call.block && Hashira::Smells::Origin.new(call.receiver).self?

  def names
    return @_names if @_names
    home = @method.home
    swept = home.accept(Hashira::Smells::Scope).sweep + @ties.homes(home.to_s).flat_map { Hashira::Smells::Scope.new(it).sweep }
    @_names = Hashira::Smells::Attributes.new(swept).readers.to_set
  end
end
