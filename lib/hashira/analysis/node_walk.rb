# frozen_string_literal: true

module Hashira
  module Analysis
    module NodeWalk
      module_function

      def each(node, &)
        yield(node)
        node.compact_child_nodes.each { each(it, &) }
      end

      def collect(node)
        found = []
        each(node) { found << it }
        found
      end
    end
  end
end
