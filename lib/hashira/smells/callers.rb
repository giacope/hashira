# frozen_string_literal: true

require "prism"

class Hashira::Smells::Callers
  WRITES = [Prism::LocalVariableWriteNode, Prism::OptionalParameterNode].freeze

  NAMED = [Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode, Prism::CallNode].freeze

  LITERALS = {
    Prism::StringNode => "String", Prism::InterpolatedStringNode => "String", Prism::SymbolNode => "Symbol",
    Prism::ArrayNode => "Array", Prism::HashNode => "Hash", Prism::IntegerNode => "Integer", Prism::FloatNode => "Float"
  }.freeze

  Site =
    Data.define(:call, :home, :definition) do
      def aimed?(subject, ownership)
        receiver = call.receiver
        return home == subject.owner if receiver.nil? || receiver.is_a?(Prism::SelfNode)
        owner = subject.owner
        kinds(receiver, subject.singleton?).any? { |path, rooted| ownership.resolve(path, home, rooted:) == owner }
      end

      def kinds(receiver, singleton)
        return constant(receiver) if singleton
        sources(receiver).flat_map { constant(it.receiver) } + named(receiver) + literal(receiver)
      end

      def named(receiver) = Hashira::Smells::Naming.new(word(receiver)).types.map { [it, false] }

      def literal(receiver) = LITERALS.filter_map { |type, name| [[name], true] if receiver.is_a?(type) }

      def constant(node)
        return [] unless Hashira::Smells::Factory.new(node).constant?
        [[Hashira::Analysis::Syntax.new(node).segments, Hashira::Analysis::Syntax.new(node).rooted?]]
      end

      def sources(receiver)
        case receiver
        when Prism::LocalVariableReadNode then writes(receiver.name)
        else [receiver].select { Hashira::Smells::Mapping.new(it).made? }
        end
      end

      def writes(name)
        Hashira::Analysis::NodeWalk.new(definition).collect.select { WRITES.include?(it.class) && it.name == name }
          .map(&:value).select { Hashira::Smells::Mapping.new(it).made? }
      end

      def word(receiver) = NAMED.include?(receiver.class) ? receiver.name.to_s.delete_prefix("@") : ""
    end

  def initialize(trees, ownership)
    @trees = trees
    @ownership = ownership
  end

  def of(subject) = sites.fetch(subject.node.name, []).select { it.aimed?(subject, @ownership) }.map(&:call)

  private

  def sites = @_sites ||= @trees.flat_map { visit(it, [], it) }.group_by { it.call.name }

  def visit(node, stack, definition)
    own = node.is_a?(Prism::CallNode) ? [Site.new(node, Array(stack.last).join("::"), definition)] : []
    inner = Hashira::Analysis::TypeWalk.new(node).type? ? stack + [place(stack, node)] : stack
    own + node.compact_child_nodes.flat_map { visit(it, inner, node.is_a?(Prism::DefNode) ? node : definition) }
  end

  def place(stack, type) = Hashira::Analysis::Syntax.new(type.constant_path).place(stack, nil)
end
