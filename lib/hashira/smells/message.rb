# frozen_string_literal: true

require "prism"

class Hashira::Smells::Message
  SENDS = %i[send public_send __send__].freeze

  NAMES = [Prism::SymbolNode, Prism::StringNode].freeze

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  HOLE = "_"

  DRAWS = %i[
    gets getc getbyte getch readline readchar readbyte readpartial read_nonblock sysread
    recv recvfrom recv_nonblock recvmsg accept_nonblock pop shift deq
  ].freeze

  BANG = /\w!\z/

  CHANGES = (DRAWS + %i[<< push append unshift prepend insert concat delete delete_at delete_if clear replace]).freeze

  private_constant :DRAWS, :BANG, :CHANGES

  def initialize(call)
    @call = call
  end

  def name = SENDS.include?(@call.name) ? sent(@call.arguments&.arguments&.first) : @call.name.to_s

  def changes? = name.then { CHANGES.include?(it.to_sym) || BANG.match?(it) }

  def draws? = DRAWS.include?(@call.name)

  private

  def sent(node)
    case node
    when *NAMES then Hashira::Analysis::Syntax.new(node).text
    when *INTERPOLATED then node.parts.map { sent(it).then { |part| part.empty? ? HOLE : part } }.join
    else ""
    end
  end
end
