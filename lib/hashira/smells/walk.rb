# frozen_string_literal: true

class Hashira::Smells::Walk
  def initialize(trees)
    @trees = trees
  end

  def to_a
    @_to_a ||= @trees.flat_map { Hashira::Analysis::TypeWalk.new(it).to_enum(:walk).map { |node, full| [node, full] } }
  end

  def claimed(catalog) = to_a.select { |_node, full| catalog.claimed?(full) }

  def constants(catalog)
    claimed(catalog).flat_map do |node, full|
      Hashira::Analysis::Syntax::Body.new(node).constants.map { [full + [it.name.to_s], it] }
    end
  end
end
