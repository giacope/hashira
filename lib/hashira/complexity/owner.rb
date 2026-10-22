# frozen_string_literal: true

require "prism"

module Hashira
  module Complexity
    RECURSION = "recursion"

    Site =
      Data.define(:owner, :node) do
        def subject = owner.subject(node)

        def family = subject.delete_suffix(node.name.to_s)

        def callees = Calls.new(node).names.map { "#{family}#{it}" }

        def recursion(cyclic) = cyclic.include?(subject) ? [mark] : []

        def mark = Increment.new(line: node.location.start_line, cost: 1, label: RECURSION)
      end

    Defined =
      Data.define(:call) do
        def name
          named.respond_to?(:unescaped) ? Hashira::Analysis::Syntax.new(named).symbol : :"define_method(#{named.slice})"
        end

        def named = call.arguments.arguments.first

        def body = call.block.body

        def location = call.location
      end

    Owner =
      Data.define(:segments, :separator) do
        def initialize(segments:, separator: "#") = super

        def lifted = with(separator: ".")

        def within(node) = node.is_a?(Prism::ConstantWriteNode) ? nested(node.name.to_s) : self

        def nested(name) = Owner.new(segments: segments + [name])

        def subject(node) = "#{segments.join("::")}#{singleton?(node) ? "." : separator}#{node.name}"

        def singleton?(node) = node.is_a?(Prism::DefNode) && node.receiver
      end
  end
end
