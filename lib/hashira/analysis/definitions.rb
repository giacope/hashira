# frozen_string_literal: true

module Hashira
  module Analysis
    class Definitions
      include Enumerable

      def initialize(project, trees)
        @project = project
        @trees = trees
      end

      def each(&)
        @trees.each { |file, tree| definitions_in(file, tree, &) }
      end

      def packages = @trees.keys.map { @project.package_for(it) }.uniq

      private

      def definitions_in(file, tree)
        package = @project.package_for(file)
        TypeWalk.each_definition(tree) { |node, full| yield node, full, package }
      end
    end
  end
end
