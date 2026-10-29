# frozen_string_literal: true

class Hashira::Complexity::Reach
  def initialize(root, table)
    @root = root
    @table = table
  end

  def helpers = @_helpers ||= descend(@root)

  def methods = [@root] + helpers

  def path = @_path ||= trail(parents.keys.last)

  def depth = path.size - 1

  private

  def root = @root.name

  def descend(node)
    links(node).flat_map do |name|
      helper = @table.fetch(name)
      [helper, *descend(helper)]
    end
  end

  def links(node) = Hashira::Complexity::Calls.new(node).names.select { it != node.name && @table.key?(it) }

  def parents = @_parents ||= widen([root], { root => nil })

  def widen(frontier, tree)
    return tree if frontier.empty?
    grown = frontier.reduce(tree) { |known, name| known.merge(adopted(name)) }
    widen(grown.keys - tree.keys, grown)
  end

  def adopted(name) = links(node(name)).to_h { [it, name] }

  def node(name) = name == root ? @root : @table.fetch(name)

  def trail(name) = name ? trail(parents[name]) + [name] : []
end
