# frozen_string_literal: true

require "prism"

class Hashira::Smells::Heading
  def initialize(type)
    @node = type
  end

  def parent = Hashira::Analysis::Syntax.new(superclass).segments

  def written = superclass&.slice.to_s.delete_prefix("::")

  def class? = @node.is_a?(Prism::ClassNode)

  def module? = @node.is_a?(Prism::ModuleNode)

  private

  def superclass = (@node.superclass if class?)
end
