# frozen_string_literal: true

require "prism"

class Hashira::Smells::Message
  SENDS = %i[send public_send __send__].freeze

  NAMES = [Prism::SymbolNode, Prism::StringNode].freeze

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  HOLE = "_"

  def initialize(call)
    @call = call
  end

  def name = SENDS.include?(@call.name) ? sent(@call.arguments&.arguments&.first) : @call.name.to_s

  private

  def sent(node)
    case node
    when *NAMES then Hashira::Analysis::Syntax.new(node).text
    when *INTERPOLATED then node.parts.map { sent(it).then { |part| part.empty? ? HOLE : part } }.join
    else ""
    end
  end
end
