# frozen_string_literal: true

module Hashira
  module Coupling
    class NamespacePrefix
      def initialize(definitions)
        @definitions = definitions
      end

      def infer = build(@definitions.map { |_node, full| full }.uniq, [])

      private

      def build(fulls, prefix)
        depth = prefix.length
        wrappers(fulls, depth).map { |wrapper| build(fulls.select { it[depth] == wrapper }, prefix + [wrapper]) }
          .fetch(0, prefix)
      end

      def wrappers(fulls, depth)
        wrapper, count = fulls.filter_map { it[depth] if it[depth + 1] }.tally.max_by { |_wrapper, tally| tally }
        wrapper && count == peers(fulls, depth, wrapper) ? [wrapper] : []
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
