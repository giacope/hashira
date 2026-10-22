# frozen_string_literal: true

module Hashira
  module Analysis
    class NodeWalk
      def initialize(node)
        @node = node
      end

      def each(&)
        yield(@node)
        @node.compact_child_nodes.each { NodeWalk.new(it).each(&) }
      end

      def collect
        found = []
        each { found << it }
        found
      end
    end
  end
end
