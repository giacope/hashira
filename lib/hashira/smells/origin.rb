# frozen_string_literal: true

require "prism"

class Hashira::Smells::Origin
  SELVES = [NilClass, Prism::SelfNode].freeze

  private_constant :SELVES

  def initialize(node)
    @node = node
  end

  def self? = SELVES.include?(@node.class)

  def of(method, ties)
    return [@node.name.to_s] if @node.is_a?(Prism::InstanceVariableReadNode)
    return [] unless own?
    [method.standing.singleton? ? ".#{@node.name}" : "#{placed(method, ties).join}##{@node.name}"]
  end

  private

  def placed(method, ties)
    owner = method.home.to_s
    ties.owner(owner, @node.name) - [owner]
  end

  def own? = @node.is_a?(Prism::CallNode) && !@node.arguments && Hashira::Smells::Origin.new(@node.receiver).self?
end
