# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class Block
      REOPENERS = %i[
        included prepended class_methods concerning class_eval module_eval class_exec module_exec instance_eval
        instance_exec define_method define_singleton_method
      ].freeze

      FACTORIES = { "Class" => :new, "Module" => :new, "Struct" => :new, "Data" => :define }.freeze

      FENCES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

      CAMEL = /\A[A-Z][A-Za-z0-9_]*\z/

      def initialize(call)
        @call = call
      end

      def dsl? = @call.block.is_a?(Prism::BlockNode) && !reopening? && !built? && defines?(@call.block)

      def name = named || "(#{@call.name} block, line #{@call.location.start_line})"

      private

      def reopening? = REOPENERS.include?(@call.name) && [nil, Prism::SelfNode].include?(@call.receiver&.class)

      def built? = FACTORIES[Syntax.new(@call.receiver).segments.join("::")] == @call.name

      def defines?(node)
        node.compact_child_nodes.any? { it.is_a?(Prism::DefNode) || (!FENCES.include?(it.class) && defines?(it)) }
      end

      def named = words.find { CAMEL.match?(it) }

      def words = Array(@call.arguments&.arguments).select { Syntax.new(it).word? }.map { Syntax.new(it).text }
    end
  end
end
