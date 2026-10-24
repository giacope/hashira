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

      OPENERS = %i[class_eval module_eval class_exec module_exec].freeze

      MIXERS = %i[include prepend].freeze

      EVALUATED = %i[no_tasks no_commands].freeze

      HELPERS = :helpers

      APPS = /\A(?:::)?(?:Sinatra|Padrino)::/

      REFINE = :refine

      FENCES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

      CAMEL = /\A[A-Z][A-Za-z0-9_]*\z/

      def initialize(call, host = nil)
        @call = call
        @host = host
      end

      def dsl? = @call.block.is_a?(Prism::BlockNode) && !reopening? && !built? && defines?(@call.block)

      def walker(stack)
        opened = opening
        return TypeWalk.new(opened, opens: @call.receiver) if opened
        TypeWalk.new(@call.block, block: owner(stack.last)) if stack.any? && dsl?
      end

      def opening = (mixed if Syntax.new(@call.receiver).static?)

      private

      def owner(enclosing)
        target = refined
        return [*enclosing[...-1], "#{enclosing.last} refine #{target}"] if target
        enclosing + [named || "(#{@call.name} block, line #{@call.location.start_line})"]
      end

      def reopening? = (REOPENERS.include?(@call.name) || evaluated?) && inward?

      def inward? = [nil, Prism::SelfNode].include?(@call.receiver&.class)

      def evaluated? = EVALUATED.include?(@call.name) || (@call.name == HELPERS && app?)

      def app? = @host.is_a?(Prism::ClassNode) && APPS.match?(@host.superclass&.slice.to_s)

      def refined = (@call.arguments.arguments.first.slice if Syntax.new(@call).macro?([REFINE]))

      def built? = FACTORIES[Syntax.new(@call.receiver).segments.join("::")] == @call.name

      def mixed
        return @call.block if OPENERS.include?(@call.name) && @call.block.is_a?(Prism::BlockNode)
        made = @call.arguments&.arguments&.first
        made.block if MIXERS.include?(@call.name) && anonymous?(made)
      end

      def anonymous?(node)
        node in Prism::CallNode[name: :new, receiver: Prism::ConstantReadNode[name: :Module], block: Prism::BlockNode]
      end

      def defines?(node)
        node.compact_child_nodes.any? { it.is_a?(Prism::DefNode) || (!FENCES.include?(it.class) && defines?(it)) }
      end

      def named = Array(@call.arguments&.arguments).filter_map { Syntax.new(it).literal }.find { CAMEL.match?(it) }
    end
  end
end
