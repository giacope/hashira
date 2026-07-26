# frozen_string_literal: true

module Hashira
  module Analysis
    class ConstantRegistry
      AMBIGUOUS = Object.new.freeze

      def initialize
        @declaring_package = {}
        @shorthand = {}
      end

      attr_reader :declaring_package

      def register(path, package)
        return if path.empty?

        claim(@declaring_package, path, package)
        (1...path.length).each { claim(@shorthand, path.drop(it), package) }
      end

      def package_for(path)
        found = path.length.downto(1).filter_map { claimed(path.first(it)) }.first
        found unless found == AMBIGUOUS
      end

      private

      def claim(claims, path, package)
        key = path.join("::")
        claims[key] = claims.fetch(key, package) == package ? package : AMBIGUOUS
      end

      def claimed(path)
        key = path.join("::")
        @declaring_package[key] || @shorthand[key]
      end
    end
  end
end
