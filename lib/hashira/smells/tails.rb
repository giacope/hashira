# frozen_string_literal: true

require "prism"

class Hashira::Smells::Tails
  class Slots
    def initialize(type, names)
      @type = type
      @names = names
    end

    def of(node) = node.is_a?(type) ? names.flat_map { Array(node.public_send(it)) }.compact : []

    private

    attr_reader :type, :names
  end

  FLOW = [
    Slots.new(Prism::IfNode, %i[statements subsequent]),
    Slots.new(Prism::UnlessNode, %i[statements else_clause]),
    Slots.new(Prism::ElseNode, %i[statements]),
    Slots.new(Prism::CaseNode, %i[conditions else_clause]),
    Slots.new(Prism::CaseMatchNode, %i[conditions else_clause]),
    Slots.new(Prism::WhenNode, %i[statements]),
    Slots.new(Prism::InNode, %i[statements]),
    Slots.new(Prism::BeginNode, %i[statements rescue_clause else_clause]),
    Slots.new(Prism::RescueNode, %i[statements subsequent]),
    Slots.new(Prism::EnsureNode, %i[statements]),
    Slots.new(Prism::ParenthesesNode, %i[body]),
    Slots.new(Prism::RescueModifierNode, %i[expression rescue_expression]),
    Slots.new(Prism::AndNode, %i[right]),
    Slots.new(Prism::OrNode, %i[right])
  ].freeze

  private_constant :FLOW

  def initialize(slots = FLOW)
    @slots = slots
  end

  def widened(slots) = Hashira::Smells::Tails.new(@slots + slots)

  def reach(seeds) = Set.new.compare_by_identity.merge(seeds.flat_map { spread(it) })

  def parts(node) = @slots.flat_map { it.of(node) }

  private

  def sequence(node) = node.is_a?(Prism::StatementsNode) ? node.body : []

  def spread(node) = [node] + tails(node).flat_map { spread(it) }

  def tails(node) = parts(node) + sequence(node).last(1)
end
