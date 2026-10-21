# frozen_string_literal: true

require "prism"

module Hashira::Smells::Exits
  RAISES = %i[raise fail].freeze

  module_function

  def raise?(node) = node.is_a?(Prism::CallNode) && !node.receiver && RAISES.include?(node.name)
end
