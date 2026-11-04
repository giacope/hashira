# frozen_string_literal: true

class Hashira::Smells::Framing
  def initialize(foreign, openings, tree)
    @foreign = foreign
    @openings = openings
    @tree = tree
  end

  def framed?(name) = lineage(name).any? { @foreign.include?(it) }

  def root(name)
    framed = lineage(name).lazy.select { @foreign.include?(it) }.first(1)
    Hashira::Smells::Descent.new(framed.flat_map { @openings.fetch(it) }).parent.join("::")
  end

  private

  def lineage(name) = [name, *@tree.ancestors(name)]
end
