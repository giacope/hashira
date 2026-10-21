# frozen_string_literal: true

module Hashira::Engine
  PARENTS = %w[Rails::Engine ::Rails::Engine].freeze

  module_function

  def namespace(file)
    found = []
    Hashira::Analysis::TypeWalk.each(Hashira::Trees.parse(file)) { |node, full| found << full[0...-1] if engine?(node) }
    found.first&.join("::")
  end

  def engine?(node) = node.is_a?(Prism::ClassNode) && PARENTS.include?(node.superclass&.slice)
end
