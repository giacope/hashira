# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Owner
  INSTANCE = "#"

  SINGLETON = "."

  def initialize(segments, separator = INSTANCE)
    @segments = segments
    @separator = separator
  end

  def lifted = Hashira::Complexity::Owner.new(@segments, SINGLETON)

  def within(node)
    node.is_a?(Prism::ConstantWriteNode) ? Hashira::Complexity::Owner.new(@segments + [node.name.to_s]) : self
  end

  def subject(node) = "#{@segments.join("::")}#{singleton?(node) ? SINGLETON : @separator}#{node.name}"

  def family(node) = subject(node).delete_suffix(node.name.to_s)

  private

  def singleton?(node) = node.is_a?(Prism::DefNode) && node.receiver
end
