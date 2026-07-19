# frozen_string_literal: true

module Hashira
  module Diagram
    class Mermaid
      def initialize(edges)
        @edges = edges
        @nodes = {}
      end

      def source
        lines = @edges.map { |from, to, weight| "  #{node(from)} -->|#{weight}| #{node(to)}" }
        "graph LR\n#{lines.join("\n")}"
      end

      private

      def node(package)
        @nodes[package] ||= "#{package.gsub(/\W/, "_")}[\"#{package}\"]"
      end
    end
  end
end
