# frozen_string_literal: true

class Hashira::Complexity::Reach
  def initialize(entry, table)
    @entry = entry
    @table = table
  end

  def helpers = @_helpers ||= [].tap { |found| descend(@entry.node, found) }

  def path = @_path ||= trail(parents.keys.last)

  def depth = path.size - 1

  private

  def root = @entry.node.name

  def descend(node, found)
    links(node).each do |name|
      found << @table.fetch(name)
      descend(found.last.node, found)
    end
  end

  def links(node) = Hashira::Complexity::Calls.new(node).names.select { it != node.name && @table.key?(it) }

  def parents = @_parents ||= { root => nil }.tap { |tree| widen([root], tree) }

  def widen(frontier, tree) = frontier.empty? || widen(frontier.flat_map { adopt(it, tree) }, tree)

  def adopt(name, tree) = links(node(name)).reject { tree.key?(it) }.each { tree[it] = name }

  def node(name) = name == root ? @entry.node : @table.fetch(name).node

  def trail(name) = name ? trail(parents[name]) + [name] : []
end
