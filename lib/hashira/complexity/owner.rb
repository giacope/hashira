# frozen_string_literal: true

require "prism"

module Hashira
  module Complexity
    Site =
      Data.define(:owner, :node) do
        def subject = owner.subject(node)
      end

    Owner =
      Data.define(:segments, :separator) do
        def initialize(segments:, separator: "#") = super

        def lifted = with(separator: ".")

        def within(node) = node.is_a?(Prism::ConstantWriteNode) ? nested(node.name.to_s) : self

        def nested(name) = Owner.new(segments: segments + [name])

        def subject(node) = "#{segments.join("::")}#{node.receiver ? "." : separator}#{node.name}"
      end
  end
end
