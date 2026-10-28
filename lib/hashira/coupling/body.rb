# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Body
  MAKERS = [[%w[Class], :new], [%w[Struct], :new], [%w[Data], :define]].freeze

  private_constant :MAKERS

  def initialize(value)
    @value = value
  end

  def built? = @value.is_a?(Prism::CallNode) && MAKERS.include?(maker)

  private

  def maker = [Hashira::Analysis::Syntax.new(@value.receiver).segments, @value.name]
end
