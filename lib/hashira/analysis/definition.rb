# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    Definition =
      Data.define(:node, :path, :folder) do
        def name = path.first

        def nested? = path.length > 1

        def klass? = node.is_a?(Prism::ClassNode)

        def singular? = klass? && !nested?

        def superclass = node.superclass

        def counted? = klass? || !Hashira::Analysis::Syntax.direct(node).empty?
      end
  end
end
