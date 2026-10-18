# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Mentions
  SENDS = (
    Hashira::Analysis::Syntax::SENDS +
    %i[try try! public_method instance_method public_instance_method respond_to? define_method alias_method]
  ).freeze

  MARKERS = %i[
    private public protected module_function private_class_method public_class_method private_constant public_constant
  ].freeze

  REFLECTIONS = %i[subclasses descendants].freeze

  TOKEN = /[A-Za-z_]\w*[?!=]?/

  STEM = /\A[a-z_]\w*\z/

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  WRITES = [Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode].freeze

  Found = Data.define(:names, :prefixes, :open, :registries)

  def initialize(trees)
    @trees = trees
  end

  def found
    return @_found if @_found
    @_found = Found.new(names: Set.new, prefixes: Set.new, open: Set.new.compare_by_identity, registries: Set.new)
    @trees.each_value { visit(it, nil) }
    @_found
  end

  private

  def names = found.names

  def prefixes = found.prefixes

  def open = found.open

  def registries = found.registries

  def visit(node, owner)
    note(node, owner)
    inner = Hashira::Analysis::TypeWalk.type?(node) ? node : owner
    children(node).each { visit(it, inner) }
  end

  def children(node) = marker?(node) ? node.arguments.arguments.grep_v(Prism::SymbolNode) : node.compact_child_nodes

  def marker?(node) = node.is_a?(Prism::CallNode) && MARKERS.include?(node.name) && node.receiver.nil? && node.arguments

  def note(node, owner)
    case node
    when Prism::CallNode then called(node, owner)
    when Prism::SymbolNode then names << Hashira::Analysis::Syntax.text(node)
    when Prism::StringNode then said(Hashira::Analysis::Syntax.text(node))
    when *INTERPOLATED then stem(node.parts.first)
    when *WRITES then names.merge([node.read_name.to_s, node.write_name.to_s])
    end
  end

  def called(call, owner)
    names << call.name.to_s
    open << owner if owner && dynamic?(call)
    registries << Hashira::Analysis::Syntax.segments(call.receiver).last if REFLECTIONS.include?(call.name)
  end

  def dynamic?(call)
    first = call.arguments&.arguments&.first
    SENDS.include?(call.name) && own?(call.receiver) && !(first.is_a?(Prism::SymbolNode) || first.is_a?(Prism::StringNode))
  end

  def own?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def said(text) = text.scan(TOKEN) { names << it }

  def stem(part)
    text = Hashira::Analysis::Syntax.text(part) if part.is_a?(Prism::StringNode)
    prefixes << text if text&.match?(STEM)
  end
end
