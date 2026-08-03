# frozen_string_literal: true

module Hashira
  module Coupling
    module NamespacePrefix
      module_function

      def infer(definitions)
        build(definitions.map { |_node, full, _package| full }.uniq)
      end

      def build(fulls, prefix = [])
        depth = prefix.length
        wrapper = wrapper(fulls, depth)
        return prefix unless wrapper
        build(fulls.select { it[depth] == wrapper }, prefix + [wrapper])
      end

      def wrapper(fulls, depth)
        wrapper, count = fulls.filter_map { it[depth] if it[depth + 1] }.tally.max_by { |_wrapper, tally| tally }
        wrapper if wrapper && count == peers(fulls, depth, wrapper)
      end

      def peers(fulls, depth, wrapper)
        fulls.count do |full|
          size = full.length
          size > depth && !(size == depth + 1 && full[depth] == wrapper)
        end
      end
    end
  end
end
