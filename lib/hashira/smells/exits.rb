# frozen_string_literal: true

require "prism"

class Hashira::Smells::Exits
  RAISES = %i[raise fail].freeze

  def initialize(node)
    @node = node
  end

  def raise? = @node.is_a?(Prism::CallNode) && !@node.receiver && RAISES.include?(@node.name)
end
