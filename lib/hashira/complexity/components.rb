# frozen_string_literal: true

class Hashira::Complexity::Components
  Search =
    Data.define(:graph, :index, :low, :stack, :work, :found) do
      def run
        graph.each_key { start(it) unless index.key?(it) }
        found
      end
      private
      def start(root)
        work.push([root, enter(root)])
        step until work.empty?
      end

      def enter(node)
        low[node] = index[node] = index.size
        stack.push(node)
        0
      end

      def step
        node, position = work.last
        child = graph.fetch(node)[position]
        child ? advance(node, child) : finish
      end

      def advance(node, child)
        work.last[-1] += 1
        return work.push([child, enter(child)]) unless index.key?(child)
        lower(node, index[child]) if low.key?(child)
      end

      def finish
        node, = work.pop
        least = low[node]
        parent = work.last
        lower(parent.first, least) if parent
        close(node) if least == index[node]
      end

      def lower(node, value) = low[node] = [low[node], value].min

      def close(node)
        component = []
        component << take until component.last == node
        found << component
      end

      def take = stack.pop.tap { low.delete(it) }
    end

  def initialize(graph)
    @graph = graph
  end

  def to_a = Search.new(graph: @graph, index: {}, low: {}, stack: [], work: [], found: []).run
end
