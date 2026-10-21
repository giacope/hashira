# frozen_string_literal: true

class Hashira::Smells::Sides
  BARE = /(?:\A|::)(?:Fake|Null|Stub|Dummy|Mock)s?\z/

  def initialize(surface)
    @surface = surface
  end

  def of(name) = (BARE.match?(name) ? beside(name) : Set.new)

  private

  def beside(name)
    space = name.split("::")[...-1]
    @surface.keys.select { it != name && it.split("::")[...-1] == space && shared?(name, it) }.to_set
  end

  def shared?(name, other) = @surface.fetch(name).intersect?(@surface.fetch(other))
end
