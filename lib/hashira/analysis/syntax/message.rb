# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax::Message
  SENDS = %i[send public_send __send__ method].freeze

  TYPE_TESTS = %i[is_a? kind_of? instance_of?].freeze

  private_constant :SENDS, :TYPE_TESTS

  def initialize(node)
    @node = node
  end

  def dispatch? = @node.is_a?(Prism::CallNode) && SENDS.include?(@node.name)

  def type_test? = @node.is_a?(Prism::CallNode) && TYPE_TESTS.include?(@node.name)

  def apart? = @node.is_a?(Prism::CallNode) && Hashira::Analysis::Block.new(@node).apart?

  def origins
    sent = @node.is_a?(Prism::CallNode) && @node.receiver
    sent ? Hashira::Analysis::Syntax::Message.new(sent).origins : Hashira::Analysis::Syntax.new(@node).segments.first(1)
  end
end
