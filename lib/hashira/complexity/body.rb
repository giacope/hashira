# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Body
  LIFTING_BLOCKS = %i[class_methods].freeze

  def initialize(node, owner)
    @node = node
    @owner = owner
  end

  def each(&) = children.each { visit(it, &) }

  private

  def children = @node ? @node.compact_child_nodes : []

  def visit(child, &)
    case child
    when Prism::DefNode then yield(Hashira::Complexity::Site.new(owner: @owner, node: child))
    when Prism::CallNode then inner(child, LIFTING_BLOCKS.include?(child.name) ? @owner.lifted : @owner).each(&)
    else enter(child, &)
    end
  end

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
