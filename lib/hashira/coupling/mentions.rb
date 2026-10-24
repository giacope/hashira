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

  SENT = %i[send __send__].freeze

  STATIC = [NilClass, Prism::ConstantReadNode].freeze

  TOKEN = /[A-Za-z_]\w*[?!=]?/

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  WRITES = [Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode].freeze

  EVALS = %i[eval class_eval module_eval instance_eval].freeze

  Found =
    Data.define(:names, :prefixes, :suffixes, :open, :registries, :handed, :reflected, :evaluated) do
      def evaluated?(name) = evaluated.include?(name.split("::")[...-1])
    end

  def initialize(trees, roots = nil)
    @trees = trees
    @roots = roots
  end

  def found
    return @_found if @_found
    @_found = Found.new(
      names: Set.new, prefixes: Set.new, suffixes: Set.new, open: Set.new.compare_by_identity, registries: Set.new,
      handed: [], reflected: [], evaluated: Set.new
    )
    @trees.each_value { visit(it, nil, []) }
    @_found
  end

  private

  def names = found.names

  def visit(node, owner, nesting)
    note(node, owner, nesting)
    return children(node).each { visit(it, owner, nesting) } unless Hashira::Analysis::TypeWalk.new(node).type?
    inner = nesting + [Hashira::Analysis::Syntax.new(node.constant_path).place(nesting, @roots)]
    children(node).each { visit(it, node, inner) }
  end

  def children(node) = marker?(node) ? node.arguments.arguments.grep_v(Prism::SymbolNode) : node.compact_child_nodes

  def marker?(node) = node.is_a?(Prism::CallNode) && MARKERS.include?(node.name) && node.receiver.nil? && node.arguments

  def note(node, owner, nesting)
    case node
    when Prism::CallNode then called(node, owner, nesting)
    when Prism::SymbolNode then names << Hashira::Analysis::Syntax.new(node).text
    when Prism::StringNode then said(Hashira::Analysis::Syntax.new(node).text)
    when *INTERPOLATED then built(node.parts)
    when *WRITES, Prism::ConstantPathNode then named(node)
    end
  end

  def named(node)
    return names.merge([node.read_name.to_s, node.write_name.to_s]) unless node.is_a?(Prism::ConstantPathNode)
    names << node.name.to_s if indirect?(node.parent)
  end

  def indirect?(scope) = scope.is_a?(Prism::ConstantPathNode) ? indirect?(scope.parent) : !STATIC.include?(scope.class)

  def called(call, owner, nesting)
    names << call.name.to_s
    opened(call, owner)
    found.registries << Hashira::Analysis::Syntax.new(call.receiver).segments.last if REFLECTIONS.include?(call.name)
    passed(call, owner, nesting)
  end

  def passed(call, owner, nesting)
    found.evaluated.merge(nesting) if evaluates?(call)
    found.handed.concat(Hashira::Coupling::Gift.new(call, nesting).to_a) if handing?(call)
    mirror(call.receiver, owner) if call.name == :const_get && computed?(call)
  end

  def mirror(receiver, owner)
    read = Hashira::Analysis::Syntax.new(receiver)
    if own?(receiver)
      found.reflected << [owner, nil]
    elsif read.static?
      found.reflected << [(owner unless read.rooted?), read.segments]
    end
  end

  def evaluates?(call)
    EVALS.include?(call.name) && call.arguments&.arguments&.first.is_a?(Prism::InterpolatedStringNode)
  end

  def opened(call, owner) = (found.open << owner if owner && dynamic?(call))

  def handing?(call) = (hands?(call) || call.name.start_with?("register")) && !own?(call.receiver)

  def hands?(call) = HANDS.include?(call.name) || (SENT.include?(call.name) && HANDS.include?(message(call)))

  def message(call)
    first = call.arguments&.arguments&.first
    Hashira::Analysis::Syntax.new(first).symbol if first.is_a?(Prism::SymbolNode)
  end

  def dynamic?(call) = SENDS.include?(call.name) && own?(call.receiver) && computed?(call)

  def computed?(call)
    first = call.arguments&.arguments&.first
    !(first.nil? || first.is_a?(Prism::SymbolNode) || first.is_a?(Prism::StringNode))
  end

  def own?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def said(text) = text.scan(TOKEN) { names << it }

  def built(parts)
    head, tail = Hashira::Coupling::Affixes.new(parts).to_a
    found.prefixes << head unless head.empty?
    found.suffixes << tail unless tail.empty?
  end
end
