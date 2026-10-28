# frozen_string_literal: true

require "prism"

class Hashira::Smells::Origin
  SELVES = [NilClass, Prism::SelfNode].freeze

  private_constant :SELVES

  def initialize(node)
    @node = node
  end

  def self? = SELVES.include?(@node.class)

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

  def own? = @node.is_a?(Prism::CallNode) && !@node.arguments && Hashira::Smells::Origin.new(@node.receiver).self?
end
