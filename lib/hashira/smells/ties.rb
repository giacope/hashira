# frozen_string_literal: true

class Hashira::Smells::Ties
  def self.build(trees, walk, ownership, ancestry = Hashira::Smells::Ancestry.new(walk, ownership))
    new(ancestry, Hashira::Smells::Fillings.new(walk, ownership, ancestry), Hashira::Smells::Nulls.new(trees))
  end

  def initialize(ancestry, fillings, nulls)
    @ancestry = ancestry
    @fillings = fillings
    @nulls = nulls
  end

  def owner(name, selector) = @ancestry.owner(name, selector)

  def homes(name) = @ancestry.up(name).flat_map { @ancestry.openings(it) }

  def types(name, owner) = @fillings.types(name, owner)

  def null?(path, name) = @nulls.answer?(path, name)
end
