# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Form
  ENGINES = %w[Rails::Engine ::Rails::Engine].freeze

  private_constant :ENGINES

  def initialize(node)
    @node = node
  end

  def to_a = body.to_a

  def klass? = @node.is_a?(Prism::ClassNode)

  def type? = klass? || module?

  def counted? = klass? || (module? && !body.direct.empty?)

  def held? = value? || engine?

  private

  def body = Hashira::Analysis::Syntax::Body.new(@node)

  def module? = @node.is_a?(Prism::ModuleNode)

  def value? = @node.is_a?(Prism::ConstantWriteNode) && !Hashira::Coupling::Body.new(@node.value).built?

  def engine? = klass? && ENGINES.include?(@node.superclass&.slice)
end
