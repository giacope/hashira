# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Statements
  OPENED = [Prism::DefNode, Prism::RescueNode, Prism::WhenNode].freeze

  def initialize(roots)
    @roots = roots
  end

  def to_a = bodies.map(&:body).fetch(0, @roots)

  def opened? = @roots.one? && OPENED.include?(@roots.first.class)

  private

  def bodies = opened? ? @roots.first.compact_child_nodes.grep(Prism::StatementsNode).first(1) : []
end
