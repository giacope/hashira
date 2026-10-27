# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    class Parameters
      NAMELESS = [Prism::ForwardingParameterNode, Prism::ImplicitRestNode, Prism::NoKeywordsParameterNode].freeze

      def initialize(definition)
        @definition = definition
      end

      def names = parts.flat_map { expand(it) }

      def arguments = parts.grep_v(Prism::BlockParameterNode).flat_map { expand(it) }

      def parts
        node = @definition.parameters
        return [] unless node
        node.requireds + node.optionals + node.posts + node.keywords +
          [node.rest, node.keyword_rest, node.block].compact
      end

      private

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
      Data.define(:owner, :node, :file, :section, :ownership, :host, :protocol, :home) do
        def subject = "#{owner}#{singleton? ? "." : "#"}#{node.name}"

        def line = node.location.start_line

        def singleton? = node.receiver.is_a?(Prism::Node) || section == :singleton

        def mixin? = section == :module_function

        def polymorphic? = protocol.include?(node.name)

        def public? = section == :public && !singleton?

        def parameters = Parameters.new(node).names

        def arguments = Parameters.new(node).arguments

        def site = "#{file}:#{line}"

        def content = [node.parameters, node.body].compact

        def neighbors = Hashira::Analysis::TypeWalk.new(home).sections.map { |definition, _| definition.name }
      end

    Sketch =
      Data.define(:name, :node, :kind, :file, :lexical, :handed) do
        def initialize(handed: true, **) = super

        def parent = (node.superclass if node.is_a?(Prism::ClassNode))

        def owner = kind == :module && handed ? name.delete_suffix(Hashira::Smells::Concerns::LEVEL) : name

        def settle(protocol:, ownership:, **facts)
          TypeContext.new(name:, node:, kind:, file:, defs: defs(protocol, ownership), **facts)
        end

        def defs(protocol, ownership)
          walk = Hashira::Analysis::TypeWalk.new(node)
          (handed ? walk.sections : walk.written).map do |definition, section|
            MethodContext.new(
              owner: definition.receiver ? name : owner, node: definition, file:, section:, ownership:, host: kind,
              protocol:, home: node
            )
          end
        end
      end

    TypeContext =
      Data.define(:name, :node, :kind, :file, :defs, :assigned, :heirs, :claimed) do
        def initialize(assigned: nil, heirs: [], **rest) = super

        def line = node.location.start_line

        def owned = defs.reject(&:singleton?)

        def site = "#{file}:#{line}"
      end
  end
end
