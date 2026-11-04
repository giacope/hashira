# frozen_string_literal: true

require "prism"
require_relative "tails"

class Hashira::Smells::Discards
  Slots = Hashira::Smells::Tails::Slots

  YIELDED = [Slots.new(Prism::CallNode, %i[block]), Slots.new(Prism::BlockNode, %i[body])].freeze

  CARRIED = Hashira::Smells::Tails.new.widened(YIELDED)

  DROPPED = Hashira::Smells::Tails.new(
    [
      Slots.new(Prism::WhileNode, %i[statements]),
      Slots.new(Prism::UntilNode, %i[statements]),
      Slots.new(Prism::ForNode, %i[statements]),
      Slots.new(Prism::BeginNode, %i[ensure_clause])
    ]
  )

  def initialize(root)
    @root = root
  end

  def include?(node) = voids.include?(node)

  private

  def voids = @_voids ||= CARRIED.reach(Hashira::Smells::Scope.new(@root).inside.flat_map { thrown(it) })

  def thrown(node) = DROPPED.parts(node) + leading(node)

  def leading(node) = node.is_a?(Prism::StatementsNode) ? node.body[0...-1] : []
end
