# frozen_string_literal: true

class Hashira::Complexity::Sections
  def initialize(trees)
    @trees = trees
  end

  def parted(parts) = Set.new.compare_by_identity.merge(@trees.flat_map { members(it, parts) })

  private

  def members(tree, parts) = walk(tree).to_enum(:walk).flat_map { |type, *| chosen(type, parts) }

  def chosen(type, parts) = walk(type).sections.filter_map { |node, part| node if parts.include?(part) }

  def walk(node) = Hashira::Analysis::TypeWalk.new(node)
end
