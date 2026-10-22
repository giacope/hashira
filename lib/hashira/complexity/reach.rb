# frozen_string_literal: true

class Hashira::Complexity::Reach
  def initialize(entry, table)
    @entry = entry
    @table = table
  end

  def helpers = @_helpers ||= descend(@entry.node)

  def path = @_path ||= trail(parents.keys.last)

  def depth = path.size - 1

  private

  def root = @entry.node.name

  def descend(node)
    links(node).flat_map do |name|
      helper = @table.fetch(name)
      [helper, *descend(helper.node)]
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

  def node(name) = name == root ? @entry.node : @table.fetch(name).node

  def trail(name) = name ? trail(parents[name]) + [name] : []
end
