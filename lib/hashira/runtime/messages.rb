# frozen_string_literal: true

class Hashira::Runtime::Messages
  SHIPPED = Hashira::Runtime::Inventory.new

  SETS = %w[universal values macros kernel].to_h { [it, SHIPPED.messages(it)] }.freeze

  private_constant :SHIPPED, :SETS

  def initialize(sets = SETS)
    @sets = sets
  end

  def universal?(name) = @sets.fetch("universal").include?(name)

  def value?(name) = @sets.fetch("values").include?(name)

  def macro?(name) = @sets.fetch("macros").include?(name)

  def kernel?(name) = @sets.fetch("kernel").include?(name)
end
