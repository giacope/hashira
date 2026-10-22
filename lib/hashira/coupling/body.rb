# frozen_string_literal: true

require "prism"

Hashira::Coupling::Body =
  Data.define(:value) do
    def built? = value.is_a?(Prism::CallNode) && Hashira::Coupling::Body::MAKERS.include?(maker)

    def maker = [Hashira::Analysis::Syntax.new(value.receiver).segments, value.name]
  end

Hashira::Coupling::Body::MAKERS = [[%w[Class], :new], [%w[Struct], :new], [%w[Data], :define]].freeze
