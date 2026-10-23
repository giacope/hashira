# frozen_string_literal: true

require "prism"

class Hashira::Smells::Opaque
  SHELLS = [Prism::XStringNode, Prism::InterpolatedXStringNode].freeze

  EVALS = %i[eval class_eval module_eval instance_eval].freeze

  PEEKS = %i[binding local_variables].freeze

  SOURCES = [Prism::StringNode, Prism::InterpolatedStringNode].freeze

  def initialize(nodes)
    @nodes = nodes
  end

  def any? = @nodes.any? { SHELLS.include?(it.class) || (it.is_a?(Prism::CallNode) && peeks?(it)) }

  def none? = !any?

  private

  def peeks?(call) = PEEKS.include?(call.name) || (EVALS.include?(call.name) && SOURCES.include?(source(call).class))

  def source(call) = call.arguments&.arguments&.first
end
