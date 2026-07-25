# frozen_string_literal: true

module Hashira
  module Analysis
    module NodeWalk
      module_function

      def each_node(node, &)
        yield(node)
        node.compact_child_nodes.each { each_node(it, &) }
      end

      def collect(node)
        found = []
        each_node(node) { found << it }
        found
      end
    end
  end
end
