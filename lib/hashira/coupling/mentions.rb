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

  HANDS = %i[include prepend extend].freeze

  TOKEN = /[A-Za-z_]\w*[?!=]?/

  STEM = /\A[a-z_]\w*\z/

  NAMESPACE = /\A(?:[A-Z]\w*::)+\z/

  TAIL = /\A(?:_\w+|[A-Z]\w*)[?!=]?\z/

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  WRITES = [Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode].freeze

  Found = Data.define(:names, :prefixes, :suffixes, :open, :registries, :handed, :reflected)

  def initialize(trees)
    @trees = trees
  end

  def found
    return @_found if @_found
    @_found = Found.new(
      names: Set.new, prefixes: Set.new, suffixes: Set.new, open: Set.new.compare_by_identity, registries: Set.new,
      handed: [], reflected: []
    )
    @trees.each_value { visit(it, nil) }
    @_found
  end

  private

  def names = found.names

  def prefixes = found.prefixes

  def suffixes = found.suffixes

  def open = found.open

  def registries = found.registries

  def handed = found.handed

  def reflected = found.reflected

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
    when *INTERPOLATED then built(node.parts)
    when *WRITES, Prism::ConstantPathNode then named(node)
    end
  end

  def named(node)
    return names.merge([node.read_name.to_s, node.write_name.to_s]) unless node.is_a?(Prism::ConstantPathNode)
    names << node.name.to_s if polymorphic?(node.parent)
  end

  def polymorphic?(parent) = parent.is_a?(Prism::SelfNode) || (parent.is_a?(Prism::CallNode) && parent.name == :class)

  def called(call, owner)
    names << call.name.to_s
    open << owner if owner && dynamic?(call)
    registries << Hashira::Analysis::Syntax.segments(call.receiver).last if REFLECTIONS.include?(call.name)
    passed(call, owner)
  end

  def passed(call, owner)
    gift(call) if handing?(call)
    mirror(call.receiver, owner) if call.name == :const_get && computed?(call)
  end

  def mirror(receiver, owner)
    if own?(receiver)
      reflected << [owner, nil] if owner
    elsif Hashira::Analysis::Syntax.static?(receiver)
      reflected << [nil, Hashira::Analysis::Syntax.segments(receiver)]
    end
  end

  def handing?(call) = (HANDS.include?(call.name) || call.name.start_with?("register")) && !own?(call.receiver)

  def gift(call)
    host = root(call.receiver)
    Array(call.arguments&.arguments).select { Hashira::Analysis::Syntax.static?(it) }.each do |given|
      handed << [host, Hashira::Analysis::Syntax.segments(given)]
    end
  end

  def root(node)
    return Hashira::Analysis::Syntax.segments(node) if Hashira::Analysis::Syntax.static?(node)
    root(node.receiver) if node.is_a?(Prism::CallNode)
  end

  def dynamic?(call) = SENDS.include?(call.name) && own?(call.receiver) && computed?(call)

  def computed?(call)
    first = call.arguments&.arguments&.first
    !(first.nil? || first.is_a?(Prism::SymbolNode) || first.is_a?(Prism::StringNode))
  end

  def own?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def said(text) = text.scan(TOKEN) { names << it }

  def built(parts)
    head, tail = [parts.first, parts.last].map { literal(it) }
    prefixes << head if head.match?(STEM) || head.match?(NAMESPACE)
    suffixes << tail if tail.length > 2 && tail.match?(TAIL)
  end

  def literal(part) = part.is_a?(Prism::StringNode) ? Hashira::Analysis::Syntax.text(part) : ""
end
