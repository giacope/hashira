# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Hand
  HANDS = %i[include prepend extend].freeze

  SENT = %i[send __send__].freeze

  LOAD = :on_load

  def initialize(call)
    @call = call
  end

  def hands? = HANDS.include?(@call.name) || (SENT.include?(@call.name) && HANDS.include?(message))

  def loaded = load? ? calls.select { Hashira::Coupling::Hand.new(it).bare? } : []

  def given = Array(@call.arguments&.arguments).filter_map { segments(it) }

  def bare? = hands? && own?(@call.receiver)

  private

  def load? = @call.name == LOAD && @call.block.is_a?(Prism::BlockNode) && !own?(@call.receiver)

  def calls = Hashira::Analysis::NodeWalk.new(@call.block).collect.grep(Prism::CallNode)

  def own?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def segments(node) = (Hashira::Analysis::Syntax.new(node).segments if Hashira::Analysis::Syntax.new(node).static?)

  def message
    first = @call.arguments&.arguments&.first
    Hashira::Analysis::Syntax.new(first).symbol if first.is_a?(Prism::SymbolNode)
  end
end
