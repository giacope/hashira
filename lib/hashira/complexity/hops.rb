# frozen_string_literal: true

class Hashira::Complexity::Hops
  def initialize(helpers)
    @helpers = helpers
  end

  def longest(node) = callees(node).map { hop(it.node) }.max_by(&:size) || []

  private

  def callees(node) = Hashira::Complexity::Calls.new(node).names.filter_map { @helpers[it] }

  def hop(node) = (Hashira::Complexity::Hollow.new(node).hollow? ? [node] : []) + longest(node)
end
