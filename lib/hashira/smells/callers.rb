# frozen_string_literal: true

require "prism"

class Hashira::Smells::Callers
  WRITES = [Prism::LocalVariableWriteNode, Prism::OptionalParameterNode].freeze

  NAMED = [Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode, Prism::CallNode].freeze

  LITERALS = {
    Prism::StringNode => "String", Prism::InterpolatedStringNode => "String", Prism::SymbolNode => "Symbol",
    Prism::ArrayNode => "Array", Prism::HashNode => "Hash", Prism::IntegerNode => "Integer", Prism::FloatNode => "Float"
  }.freeze

  class Site
    def initialize(call, home, definition)
      @call = call
      @home = home
      @definition = definition
    end

    def aimed(subject, ownership) = aimed?(subject, ownership) ? [call] : []

    def selector = call.name

    private

    def aimed?(subject, ownership)
      receiver = call.receiver
      owner = subject.home.to_s
      return home == owner if receiver.nil? || receiver.is_a?(Prism::SelfNode)
      kinds(receiver, subject.standing.singleton?).any? do |path, rooted|
        ownership.resolve(path, home, rooted:).include?(owner)
      end
    end

    def kinds(receiver, singleton)
      return constant(receiver) if singleton
      literals = LITERALS.filter_map { |type, name| [[name], true] if receiver.is_a?(type) }
      sources(receiver).flat_map { constant(it.receiver) } + named(receiver) + literals
    end

    def named(receiver)
      word = NAMED.include?(receiver.class) ? receiver.name.to_s.delete_prefix("@") : ""
      Hashira::Smells::Naming.new(word).types.map { [it, false] }
    end

    def constant(node)
      return [] unless Hashira::Smells::Factory.new(node).constant?
      [[Hashira::Analysis::Syntax.new(node).segments, Hashira::Analysis::Syntax.new(node).rooted?]]
    end

    def sources(receiver)
      local = receiver.is_a?(Prism::LocalVariableReadNode)
      found = local ? Hashira::Analysis::NodeWalk.new(definition).collect.select { written?(it, receiver.name) } : []
      (local ? found.map(&:value) : [receiver]).select { Hashira::Smells::Mapping.new(it).made? }
    end

    def written?(node, name) = WRITES.include?(node.class) && node.name == name

    attr_reader :call, :home, :definition
  end

  def initialize(trees, ownership)
    @trees = trees
    @ownership = ownership
  end

  def of(subject)
    sites.fetch(subject.accept(Hashira::Smells::Signature).name, []).flat_map { it.aimed(subject, @ownership) }
  end

  private

  def sites = @_sites ||= @trees.flat_map { visit(it, [], it) }.group_by(&:selector)

  def visit(node, stack, definition)
    own = node.is_a?(Prism::CallNode) ? [Site.new(node, Array(stack.last).join("::"), definition)] : []
    inner = Hashira::Analysis::TypeWalk.new(node).type? ? stack + [place(stack, node)] : stack
    own + node.compact_child_nodes.flat_map { visit(it, inner, node.is_a?(Prism::DefNode) ? node : definition) }
  end

  def place(stack, type) = Hashira::Analysis::Syntax.new(type.constant_path).place(stack, nil)
end
