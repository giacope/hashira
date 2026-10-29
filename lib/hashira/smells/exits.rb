# frozen_string_literal: true

require "prism"

class Hashira::Smells::Exits
  RAISES = %i[raise fail].freeze

  def initialize(node)
    @node = node
  end

  def raise? = Hashira::Analysis::Syntax::Call.new(@node).command?(RAISES)
end
