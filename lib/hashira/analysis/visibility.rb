# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Visibility
  LIFTS = %i[class_methods].freeze

  APART = [Prism::ClassNode, Prism::ModuleNode, Prism::ConstantWriteNode].freeze

  private_constant :APART

  class Scan
    NONE = [[], {}].freeze

    def initialize(host)
      @host = host
    end

    def scan(nodes, section)
      nodes.reject { apart?(it) }.reduce([[], {}, section]) do |(found, overrides, current), node|
        more, also, after = classify(node, current)
        [found + more, overrides.merge(also), after]
      end
    end

    private

    def classify(node, section)
      case node
      when Prism::DefNode then [[[node, section.last]], {}, section]
      when Prism::CallNode then heed(node, section)
      else descend(node, section)
      end
    end

    def descend(node, section)
      node.is_a?(Prism::SingletonClassNode) ? shadow(node, section) : scan(node.compact_child_nodes, section)
    end

    def apart?(node) = APART.any? { node.is_a?(it) }

    def heed(node, section)
      return shadow(node.block, section) if lift?(node)
      return switch(node.name, node.arguments, section) if bare?(node)
      block = Hashira::Analysis::Block.new(node, @host)
      return [*NONE, section] if block.dsl? || block.opening
      [*scan(node.compact_child_nodes, section).first(2), section]
    end

    def bare?(node) = Hashira::Analysis::Syntax::Call.new(node).marker?

    def lift?(node) = LIFTS.include?(node.name) && !node.receiver && node.block.is_a?(Prism::BlockNode)

    def switch(name, arguments, section)
      return [*NONE, section + [name]] unless arguments
      given = arguments.arguments
      overrides = given.grep(Prism::SymbolNode).to_h { [Hashira::Analysis::Syntax::Word.new(it).symbol, name] }
      [given.grep(Prism::DefNode).map { [it, name] }, overrides, section]
    end

    def shadow(node, section)
      [Hashira::Analysis::Visibility.new(node).entries.map { |definition, _| [definition, :singleton] }, {}, section]
    end
  end

  def initialize(type)
    @node = type
  end

  def entries = written.map { |node, section| [node, class_level? ? :singleton : section] }

  def written
    found, overrides, _section = Scan.new(@node).scan(statements(@node), [:public])
    found.map { |node, section| [node, lifted(overrides.fetch(node.name, section))] }
  end

  private

  def statements(node)
    body = node.body
    body.is_a?(Prism::StatementsNode) ? body.body : []
  end

  def lifted(section) = section == :public && extended? ? :module_function : section

  def extended? = (@_extended ||= [statements(@node).any? { reflexive?(it) }]).first

  def class_level? = Hashira::Analysis::Syntax::Body.new(@node).class_level?

  def reflexive?(node)
    node in Prism::CallNode[name: :extend, receiver: nil, arguments: Prism::ArgumentsNode[arguments: [Prism::SelfNode]]]
  end
end
