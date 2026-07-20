# frozen_string_literal: true

module Hashira
  module Analysis
    class CycleSearch
      def initialize(dependencies, package)
        @dependencies = dependencies
        @package = package
        @predecessor = {}
        @queue = dependencies[package].to_a.each { @predecessor[it] = package }
      end

      def path
        trace_back([@package]) if cycle?
      end

      private

      def cycle?
        while (node = @queue.shift)
          return true if node == @package

          visit(node)
        end
      end

      def visit(node)
        @dependencies[node].each do |neighbor|
          next if @predecessor.key?(neighbor)

          @predecessor[neighbor] = node
          @queue << neighbor
        end
      end

      def trace_back(path)
        first = path.first
        return path if first == @package && path.size > 1

        trace_back(path.unshift(@predecessor[first]))
      end
    end
  end
end
