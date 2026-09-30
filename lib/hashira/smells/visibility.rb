# frozen_string_literal: true

require "prism"

class Hashira::Smells::Visibility
  MARKERS = %i[public private protected module_function].freeze

  CLASS_LEVEL = :ClassMethods

  LIFTS = %i[class_methods].freeze

  def initialize(type)
    @node = type
  end

  def entries
    blank
    scan(statements(@node))
    @_found.map { |node, section| [node, lifted(@_overrides.fetch(node.name, section))] }
  end

  private

  def blank
    @_section = :public
    @_extended = statements(@node).any? { reflexive?(it) }
    @_overrides = {}
    @_found = []
  end

  def statements(node)
    body = node.body
    body.is_a?(Prism::StatementsNode) ? body.body : []
  end

  def lifted(section)
    return :singleton if class_level?
    section == :public && @_extended ? :module_function : section
  end

  def class_level? = @node.is_a?(Prism::ModuleNode) && @node.name == CLASS_LEVEL

  def reflexive?(node)
    node in Prism::CallNode[name: :extend, receiver: nil, arguments: Prism::ArgumentsNode[arguments: [Prism::SelfNode]]]
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
    return shadow(node.block) if lift?(node)
    bare?(node) ? switch(node.name, node.arguments) : enclose(node)
  end

  def bare?(node) = MARKERS.include?(node.name) && !node.receiver

  def lift?(node) = LIFTS.include?(node.name) && !node.receiver && node.block.is_a?(Prism::BlockNode)

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

  def enclose(node)
    outer = @_section
    scan(node.compact_child_nodes)
    @_section = outer
  end

  def shadow(node)
    @_found.concat(Hashira::Smells::Visibility.new(node).entries.map { |definition, _| [definition, :singleton] })
  end
end
