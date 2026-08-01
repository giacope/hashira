# frozen_string_literal: true

class Hashira::Duplication::UnionFind
  def initialize
    @parent = {}
  end

  def union(left, right) = @parent[root(left)] = root(right)

  def clusters = @parent.keys.group_by { root(it) }.values

  def root(node)
    @parent[node] = node unless @parent.key?(node)
    found = @parent[node]
    found == node ? node : (@parent[node] = root(found))
  end
end
