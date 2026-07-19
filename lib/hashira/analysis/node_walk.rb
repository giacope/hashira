# frozen_string_literal: true

module Hashira
  module Analysis
    module NodeWalk
      module_function

      def each_node(node, &)
        yield(node)
        node.compact_child_nodes.each { each_node(_1, &) }
      end
    end
  end
end
