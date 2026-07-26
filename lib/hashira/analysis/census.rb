# frozen_string_literal: true

module Hashira
  module Analysis
    class Census
      def initialize(project, trees)
        @definitions = Definitions.new(project, trees)
        @type_count = Hash.new(0)
        @registry = ConstantRegistry.new
        @namespace_prefix = NamespacePrefix.infer(@definitions)
        take
      end

      attr_reader :type_count, :namespace_prefix

      def declaring_package = @registry.declaring_package

      def packages = (@type_count.keys | @definitions.packages)

      def resolve(segments) = @registry.package_for(after_prefix(segments))

      private

      def take
        @definitions.each do |node, full, package|
          @registry.register(after_prefix(full), package)
          @type_count[package] += 1 unless Syntax.direct_definitions(node).empty?
        end
      end

      def after_prefix(segments)
        return [] if @namespace_prefix.first(segments.length) == segments

        depth = @namespace_prefix.length.downto(0).find { segments.first(it) == @namespace_prefix.last(it) }
        segments.drop(depth)
      end
    end
  end
end
