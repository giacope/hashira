# frozen_string_literal: true

module Hashira
  module Analysis
    class Census
      def initialize(project, trees)
        @definitions = Definitions.new(project, trees)
        @type_count = Hash.new(0)
        @declaring_package = {}
        @root_namespace = RootNamespace.infer(@definitions)
        take
      end

      attr_reader :type_count, :declaring_package, :root_namespace

      def packages = (@type_count.keys | @definitions.packages)

      def resolve(segments)
        outer, inner = segments.first(2)
        @declaring_package[outer == root_namespace ? inner : outer]
      end

      private

      def take
        @definitions.each do |node, full, package|
          register(full, package)
          @type_count[package] += 1 unless Syntax.direct_definitions(node).empty?
        end
      end

      # Assumes each top-level name is declared by one package; if two
      # packages declare the same name, the last file (in sort order) wins.
      def register(full, package)
        outer, inner = full.first(2)
        name = outer == root_namespace ? inner : outer
        @declaring_package[name] = package if name
      end
    end
  end
end
