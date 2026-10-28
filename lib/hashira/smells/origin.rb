# frozen_string_literal: true

require "prism"

class Hashira::Smells::Origin
  SELVES = [NilClass, Prism::SelfNode].freeze

  def initialize(node)
    @node = node
  end

  def of(method)
    return @node.name.to_s if @node.is_a?(Prism::InstanceVariableReadNode)
    return unless own?
    method.singleton? ? ".#{@node.name}" : "#{placed(method)}##{@node.name}"
  end

  private

  def placed(method)
    owner = method.ownership.ancestry.owner(method.owner, @node.name)
    owner unless owner == method.owner
  end

  def own? = @node.is_a?(Prism::CallNode) && !@node.arguments && SELVES.include?(@node.receiver.class)
end
