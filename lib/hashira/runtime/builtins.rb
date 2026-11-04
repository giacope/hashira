# frozen_string_literal: true

class Hashira::Runtime::Builtins
  SHIPPED = Hashira::Runtime::Inventory.new

  CORE = SHIPPED.words("constants")

  LIBRARIES = SHIPPED.words("libraries")

  HERITAGE = SHIPPED.heritage

  private_constant :SHIPPED, :CORE, :LIBRARIES, :HERITAGE

  def initialize(core = CORE, libraries = LIBRARIES, heritage = HERITAGE)
    @core = core
    @libraries = libraries
    @heritage = heritage
  end

  def core?(name) = @core.include?(name)

  def library?(root) = @libraries.include?(root.downcase)

  def heritage(parent) = @heritage.fetch(parent, Set.new)
end
