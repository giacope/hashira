# frozen_string_literal: true

require "prism"

module Fixtures
  class Readers
    HIDDEN = %i[private protected].freeze

    READERS = %i[attr_reader attr_accessor].freeze

    def initialize(library = File.expand_path("../../lib", __dir__))
      @library = library
    end

    def sites = found.select { it.first == :accept }.map { it.drop(1) }

    def named(call, scopes)
      name = call.arguments.arguments.first.slice
      [*scopes.reverse.map { "#{it}::#{name}" }, name].select { classes.key?(it) }.first(1)
    end

    def readers = sites.flat_map { |call, scopes| named(call, scopes) }.uniq

    def kept(name) = classes.fetch(name).flat_map { stored(it) }

    def answered(name) = classes.fetch(name).flat_map { exposed(it) }

    def accepts
      trees.flat_map { Hashira::Analysis::NodeWalk.new(it).collect.grep(Prism::DefNode) }.select { it.name == :accept }
    end

    private

    def trees = @_trees ||= Dir[File.join(@library, "**", "*.rb")].map { Prism.parse_file(it).value }

    def found = @_found ||= trees.flat_map { survey(it, []) }

    def classes
      @_classes ||= found.select { it.first == :class }.group_by(&:last).transform_values { it.map { it[1] } }
    end

    def survey(node, scopes)
      inner = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode) ? [*scopes, scope(scopes, node)] : scopes
      [*(node.is_a?(Prism::ClassNode) ? [[:class, node, inner.last]] : []), *sent(node, inner)] +
        node.compact_child_nodes.flat_map { survey(it, inner) }
    end

    def scope(scopes, type) = [scopes.last, type.constant_path.slice].compact.join("::")

    def sent(node, scopes)
      node.is_a?(Prism::CallNode) && node.name == :accept && node.receiver ? [[:accept, node, scopes]] : []
    end

    def statements(type) = Array(type.body&.body)

    def stored(type)
      statements(type).grep(Prism::DefNode).select { it.name == :initialize }.flat_map do |constructor|
        given = constructor.parameters.requireds.first.name
        writes = Hashira::Analysis::NodeWalk.new(constructor).collect.grep(Prism::InstanceVariableWriteNode)
        writes.select { it.value in Prism::LocalVariableReadNode[name: ^given] }.map(&:name)
      end
    end

    def exposed(type)
      open = true
      statements(type).flat_map do |statement|
        open = visible(statement, open)
        open ? answers(statement) : []
      end
    end

    def visible(statement, open)
      return open unless statement.is_a?(Prism::CallNode) && !statement.receiver && !statement.arguments
      statement.name == :public || (open && !HIDDEN.include?(statement.name))
    end

    def answers(statement)
      case statement
      when Prism::DefNode then statement.receiver || statement.name == :initialize ? [] : bare(statement.body)
      when Prism::CallNode then READERS.include?(statement.name) ? fields(statement) : []
      else []
      end
    end

    def fields(call) = call.arguments.arguments.grep(Prism::SymbolNode).map { :"@#{it.unescaped}" }

    def bare(body)
      value = body.is_a?(Prism::StatementsNode) && body.body.one? ? body.body.first : body
      value = value.elements.first if value.is_a?(Prism::ArrayNode) && value.elements.one?
      value.is_a?(Prism::InstanceVariableReadNode) ? [value.name] : []
    end
  end

  LIBRARY = Readers.new
end
