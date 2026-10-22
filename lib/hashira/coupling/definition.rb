# frozen_string_literal: true

require "prism"

module Hashira
  module Coupling
    Definition =
      Data.define(:node, :path, :folder, :scope, :file) do
        def name = path.first

        def nested? = path.length > 1

        def klass? = node.is_a?(Prism::ClassNode)

        def superclass = node.superclass

        def module? = node.is_a?(Prism::ModuleNode)

        def type? = klass? || module?

        def created? = node.is_a?(Prism::ConstantWriteNode) || (klass? && !superclass.nil?)

        def counted? = klass? || (module? && !Hashira::Analysis::Syntax.new(node).direct.empty?)

        def value? = node.is_a?(Prism::ConstantWriteNode) && !Hashira::Coupling::Body.new(node.value).built?

        def engine? = klass? && Hashira::Coupling::Definition::ENGINES.include?(superclass&.slice)
      end

    Definition::ENGINES = %w[Rails::Engine ::Rails::Engine].freeze
  end
end
