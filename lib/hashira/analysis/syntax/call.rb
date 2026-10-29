# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax::Call
  MARKERS = %i[public private protected module_function].freeze

  private_constant :MARKERS

  def initialize(node)
    @node = node
  end

  def macro?(names) = command?(names) && @node.arguments

  def command?(names) = @node.is_a?(Prism::CallNode) && !@node.receiver && names.include?(@node.name)

  def marker? = command?(MARKERS)

  def dsl?(host) = Hashira::Analysis::Block.new(@node, host).dsl?
end
