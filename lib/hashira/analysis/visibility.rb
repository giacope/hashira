# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Visibility
  LIFTS = %i[class_methods].freeze

  Scan =
    Data.define(:found, :overrides, :section) do
      def scan(nodes) = nodes.each { classify(it) }
      private
      def classify(node)
        case node
        when Prism::DefNode then found << [node, section.last]
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

      def bare?(node) = Hashira::Analysis::TypeWalk::MARKERS.include?(node.name) && !node.receiver

      def lift?(node) = LIFTS.include?(node.name) && !node.receiver && node.block.is_a?(Prism::BlockNode)

      def switch(name, arguments)
        arguments ? tag(name, arguments.arguments) : section.push(name)
      end

      def tag(name, arguments) = arguments.each { note(it, name) }

      def note(argument, name)
        case argument
        when Prism::DefNode then found << [argument, name]
        when Prism::SymbolNode then overrides[Hashira::Analysis::Syntax.symbol(argument)] = name
        end
      end

      def enclose(node)
        outer = section.size
        scan(node.compact_child_nodes)
        section.pop(section.size - outer)
      end

      def shadow(node)
        found.concat(Hashira::Analysis::Visibility.new(node).entries.map { |definition, _| [definition, :singleton] })
      end
    end

  def initialize(type)
    @node = type
  end

  def entries
    scanned = Scan.new(found: [], overrides: {}, section: [:public]).tap { it.scan(statements(@node)) }
    scanned.found.map { |node, section| [node, lifted(scanned.overrides.fetch(node.name, section))] }
  end

  private

  def statements(node)
    body = node.body
    body.is_a?(Prism::StatementsNode) ? body.body : []
  end

  def lifted(section)
    return :singleton if class_level?
    section == :public && extended? ? :module_function : section
  end

  def extended? = (@_extended ||= [statements(@node).any? { reflexive?(it) }]).first

  def class_level? = @node.is_a?(Prism::ModuleNode) && @node.name == Hashira::Analysis::TypeWalk::CLASS_LEVEL

  def reflexive?(node)
    node in Prism::CallNode[name: :extend, receiver: nil, arguments: Prism::ArgumentsNode[arguments: [Prism::SelfNode]]]
  end
end
