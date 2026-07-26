# frozen_string_literal: true

module Hashira
  module Analysis
    module NamespacePrefix
      module_function

      def infer(definitions)
        build(deepest_definition_per_package(definitions))
      end

      def build(fulls, prefix = [])
        depth = prefix.length
        wrapper = shared_wrapper(fulls, depth)
        return prefix unless wrapper

        build(fulls.select { it[depth] == wrapper }, prefix + [wrapper])
      end

      def deepest_definition_per_package(definitions)
        definitions.map { |_node, full, package| [package, full] }
                   .sort_by { |_package, full| full.length }
                   .to_h.values
      end

      def shared_wrapper(fulls, depth)
        wrapper, count = fulls.filter_map { it[depth] if it[depth + 1] }.tally.max_by { |_wrapper, tally| tally }
        wrapper if wrapper && count > fulls.size / 2
      end
    end
  end
end
