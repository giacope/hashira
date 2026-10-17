# frozen_string_literal: true

require "prism"

module Hashira
  module Coupling
    Opening =
      Data.define(:node, :full, :path, :stack, :file) do
        def klass? = node.is_a?(Prism::ClassNode)

        def class_level? = node.is_a?(Prism::ModuleNode) && full.last == Hashira::Analysis::TypeWalk::CLASS_LEVEL.to_s

        def owner = class_level? ? path[...-1] : path

        def shown = (class_level? ? full[...-1] : full).join("::")

        def statements = Hashira::Analysis::Syntax.statements(node).compact

        def hidden = calls(:private_constant).flat_map { symbols(it) }.to_set

        def calls(name)
          statements.grep(Prism::CallNode).select { it.name == name && it.receiver.nil? && it.arguments }
        end

        def symbols(call) = call.arguments.arguments.grep(Prism::SymbolNode).map(&:unescaped)

        def mixins = %i[include prepend].flat_map { calls(it) }.flat_map { it.arguments.arguments }

        def site(node) = "#{file}:#{node.location.start_line}"

        def links = supers + included

        def supers = klass? && node.superclass ? [[node.superclass, stack]] : []

        def included = mixins.map { [it, stack + [full]] }
      end
  end
end
