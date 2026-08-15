# frozen_string_literal: true

require "prism"

class Hashira::Smells::Visibility
  MARKERS = %i[public private protected module_function].freeze

  def initialize(type)
    @node = type
  end

  def entries
    blank
    scan(statements(@node))
    @_found.map { |node, section| [node, @_overrides.fetch(node.name, section)] }
  end

  private

  def blank
    @_section = :public
    @_overrides = {}
    @_found = []
  end

  def statements(node)
    body = node.body
    body.is_a?(Prism::StatementsNode) ? body.body : []
  end

  def scan(nodes) = nodes.each { classify(it) }

  def classify(node)
    case node
    when Prism::DefNode then @_found << [node, @_section]
    when Prism::CallNode then heed(node)
    else descend(node)
    end
  end

  def descend(node)
    case node
    when Prism::SingletonClassNode then shadow(node)
    when Prism::ClassNode, Prism::ModuleNode, Prism::ConstantWriteNode then nil
    else scan(node.compact_child_nodes)
    end
  end

  def heed(node)
    bare?(node) ? switch(node.name, node.arguments) : scan(node.compact_child_nodes)
  end

  def bare?(node) = MARKERS.include?(node.name) && !node.receiver

  def switch(name, arguments)
    arguments ? tag(name, arguments.arguments) : (@_section = name)
  end

  def tag(section, arguments) = arguments.each { note(it, section) }

  def note(argument, section)
    case argument
    when Prism::DefNode then @_found << [argument, section]
    when Prism::SymbolNode then @_overrides[argument.unescaped.to_sym] = section
    end
  end

  def shadow(node)
    statements(node).each { @_found << [it, :singleton] if it.is_a?(Prism::DefNode) }
  end
end
