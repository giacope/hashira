# frozen_string_literal: true

class Hashira::Duplication::UnionFind
  def initialize(pairs)
    @pairs = pairs
  end

  def clusters
    seen = Set.new
    links.keys.filter_map do |start|
      next unless seen.add?(start)
      group = [start]
      group.each { |node| links.fetch(node).each { group << it if seen.add?(it) } }
      group.sort_by { order.fetch(it) }
    end
  end

  private

  def links
    @_links ||=
      @pairs.each_with_object({}) do |(left, right), found|
        (found[left] ||= []) << right
        (found[right] ||= []) << left
      end
  end

  def order = @_order ||= links.keys.each_with_index.to_h
end
