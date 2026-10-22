# frozen_string_literal: true

require "prism"

class Hashira::Smells::Origin
  SELVES = [NilClass, Prism::SelfNode].freeze

  def initialize(node)
    @node = node
  end

  def of(singleton)
    return @node.name.to_s if @node.is_a?(Prism::InstanceVariableReadNode)
    "#{singleton ? "." : "#"}#{@node.name}" if own?
  end

  private

  def own? = @node.is_a?(Prism::CallNode) && !@node.arguments && SELVES.include?(@node.receiver.class)
end
