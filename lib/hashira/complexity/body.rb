# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Body
  LIFTING_BLOCKS = %i[class_methods].freeze

  DEFINERS = %i[define_method].freeze

  def initialize(node, owner)
    @node = node
    @owner = owner
  end

  def each(&) = children.each { visit(it, &) }

  private

  def children = @node ? @node.compact_child_nodes : []

  def visit(child, &)
    case child
    when Prism::DefNode then yield(site(child))
    when Prism::CallNode then call(child, &)
    else enter(child, &)
    end
  end

  def call(child, &)
    return yield(site(Hashira::Complexity::Defined.new(child))) if defines?(child)
    inner(child, LIFTING_BLOCKS.include?(child.name) ? @owner.lifted : @owner).each(&)
  end

  def site(node) = Hashira::Complexity::Site.new(owner: @owner, node:)

  def defines?(call) = DEFINERS.include?(call.name) && !call.receiver && call.arguments && block?(call)

  def block?(call) = call.block.is_a?(Prism::BlockNode)

  def enter(child, &)
    case child
    when Prism::SingletonClassNode then opened(child).each(&)
    when Prism::ClassNode, Prism::ModuleNode then nil
    else inner(child, @owner.within(child)).each(&)
    end
  end

  def opened(child) = child.expression.is_a?(Prism::SelfNode) ? inner(child, @owner.lifted) : []

  def inner(child, owner) = Hashira::Complexity::Body.new(child, owner)
end
