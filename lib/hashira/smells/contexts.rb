# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    module Parameters
      NAMELESS = [Prism::ForwardingParameterNode, Prism::ImplicitRestNode, Prism::NoKeywordsParameterNode].freeze

      module_function

      def names(definition) = parts(definition).flat_map { expand(it) }

      def arguments(definition) = parts(definition).grep_v(Prism::BlockParameterNode).flat_map { expand(it) }

      def parts(definition)
        node = definition.parameters
        return [] unless node
        node.requireds + node.optionals + node.posts + node.keywords +
          [node.rest, node.keyword_rest, node.block].compact
      end

      def expand(part)
        case part
        when Prism::MultiTargetNode then pieces(part).flat_map { expand(it) }
        when *NAMELESS then []
        else [part.name].compact
        end
      end

      def pieces(part) = part.lefts + Array(part.rest&.expression) + part.rights
    end

    MethodContext =
      Data.define(:owner, :node, :file, :section, :ownership) do
        def subject = "#{owner}#{singleton? ? "." : "#"}#{node.name}"

        def line = node.location.start_line

        def singleton? = node.receiver.is_a?(Prism::Node) || section == :singleton

        def mixin? = section == :module_function

        def public? = section == :public && !singleton?

        def parameters = Parameters.names(node)

        def arguments = Parameters.arguments(node)

        def site = "#{file}:#{line}"
      end

    TypeContext =
      Data.define(:name, :node, :kind, :file, :defs) do
        def line = node.location.start_line

        def subject = name

        def owned = defs.reject(&:singleton?)

        def site = "#{file}:#{line}"
      end
  end
end
