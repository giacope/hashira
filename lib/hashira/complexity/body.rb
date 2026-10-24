# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Body
  LIFTING_BLOCKS = %i[class_methods].freeze

  DEFINERS = %i[define_method].freeze

  def initialize(node, owner, host = nil)
    @node = node
    @owner = owner
    @host = host
  end

  def each(&) = (@node ? @node.compact_child_nodes : []).each { visit(it, &) }

  private

  def visit(child, &)
    case child
    when Prism::DefNode then yield(site(child))
    when Prism::CallNode then call(child, &)
    else enter(child, &)
    end
  end

  def call(child, &)
    return yield(site(Hashira::Complexity::Defined.new(child))) if defines?(child)
    return if Hashira::Analysis::TypeWalk.new(child).dsl?(@host)
    inner(child, LIFTING_BLOCKS.include?(child.name) ? @owner.lifted : @owner).each(&)
  end

  def site(node) = Hashira::Complexity::Site.new(owner: @owner, node:)

  def defines?(call) = DEFINERS.include?(call.name) && !call.receiver && call.arguments && block?(call)

  def block?(call) = call.block.is_a?(Prism::BlockNode)

  def enter(child, &)
    case child
    when Prism::SingletonClassNode then inner(child, @owner.lifted).each(&) if child.expression.is_a?(Prism::SelfNode)
    when Prism::ClassNode, Prism::ModuleNode then nil
    else inner(child, @owner.within(child)).each(&)
    end
  end

  def inner(child, owner) = Hashira::Complexity::Body.new(child, owner, @host)
end
