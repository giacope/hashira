# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module Syntax
      module_function

      def path_segments(node)
        case node
        when Prism::ConstantReadNode then [node.name.to_s]
        when Prism::ConstantPathNode then path_segments(node.parent) + name_of(node)
        else []
        end
      end

      def name_of(node) = [node.name.to_s]

      def direct_definitions(type_node)
        body = type_node.body
        statements = body.is_a?(Prism::StatementsNode) ? body.body : [body]
        statements.grep(Prism::DefNode)
      end
    end
  end
end
