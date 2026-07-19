# frozen_string_literal: true

module Hashira
  module Analysis
    class EdgeMap
      def initialize(project, census)
        @project = project
        @census = census
        @dependencies = empty_sets
        @evidence = empty_sets
      end

      attr_reader :dependencies, :evidence

      def record(file, tree)
        from = @project.package_for(file)
        source = @project.relative(file)
        References.each_sighting(tree).each do |segments, line|
          record_reference(from, source, segments, line)
        end
      end

      private

      def empty_sets = Hash.new { |hash, key| hash[key] = Set.new }

      def record_reference(from, source, segments, line)
        to = @census.resolve(segments)
        return unless to && to != from

        @dependencies[from] << to
        @evidence[[from, to]] << "#{source}:#{line}: #{segments.join("::")}"
      end
    end
  end
end
