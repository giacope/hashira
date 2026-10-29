# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Mentions
  SENDS = %i[
    try try! public_method instance_method public_instance_method respond_to? define_method alias_method
  ].freeze

  MARKERS = %i[
    private public protected module_function private_class_method public_class_method private_constant public_constant
  ].freeze

  REFLECTIONS = %i[subclasses descendants].freeze

  STATIC = [NilClass, Prism::ConstantReadNode].freeze

  TOKEN = /[A-Za-z_]\w*[?!=]?/

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  WRITES = [Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode].freeze

  EVALS = %i[eval class_eval module_eval instance_eval].freeze

  NAMED = [NilClass, Prism::SymbolNode, Prism::StringNode].freeze

  def initialize(trees, roots = nil)
    @trees = trees
    @roots = roots
  end

  def spoken(heard, referenced)
    Hashira::Coupling::Spoken.new(names, heard, Hashira::Coupling::Stems.new(prefixes, suffixes), referenced)
  end

  def marks(census, openings)
    reflection = Hashira::Coupling::Reflection.new(reflected, census, openings)
    Hashira::Coupling::Marks.new(evaluated, senders.flat_map { openings.home(it) }.to_set, reflection)
  end

  def registry(heritage, routines, openings) = Hashira::Coupling::Registry.new(heritage, routines, registries, openings)

  def handover(census, told) = Hashira::Coupling::Handover.new(handed, census, told)

  private

  def notes
    return @_notes if @_notes
    @_notes = [Set.new, Set.new, Set.new, Set.new.compare_by_identity, Set.new, [], [], Set.new]
    @trees.each_value { visit(it, nil, []) }
    @_notes
  end

  def names = notes.fetch(0)

  def prefixes = notes.fetch(1)

  def suffixes = notes.fetch(2)

  def senders = notes.fetch(3)

  def registries = notes.fetch(4)

  def handed = notes.fetch(5)

  def reflected = notes.fetch(6)

  def evaluated = notes.fetch(7)

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
    when Prism::SymbolNode then names << Hashira::Analysis::Syntax::Word.new(node).to_s
    when Prism::StringNode then said(Hashira::Analysis::Syntax::Word.new(node).to_s)
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
    registries << Hashira::Analysis::Syntax.new(call.receiver).segments.last if REFLECTIONS.include?(call.name)
    passed(call, owner, nesting)
  end

  def passed(call, owner, nesting)
    evaluated.merge(nesting) if evaluates?(call)
    handed.concat(gifts(call, nesting))
    mirror(call.receiver, owner) if call.name == :const_get && computed?(call)
  end

  def mirror(receiver, owner)
    read = Hashira::Analysis::Syntax.new(receiver)
    return reflected << [owner, nil] if own?(receiver)
    reflected << [(owner unless read.rooted?), read.segments] if read.static?
  end

  def evaluates?(call)
    EVALS.include?(call.name) && call.arguments&.arguments&.first.is_a?(Prism::InterpolatedStringNode)
  end

  def opened(call, owner) = (senders << owner if owner && dynamic?(call))

  def handing?(call) = (hand(call).hands? || call.name.start_with?("register")) && !own?(call.receiver)

  def gifts(call, nesting)
    loaded = hand(call).loaded.map { Hashira::Coupling::Gift.new(it, nesting, call.receiver) }
    (handing?(call) ? [Hashira::Coupling::Gift.new(call, nesting), *loaded] : loaded).flat_map(&:to_a)
  end

  def hand(call) = Hashira::Coupling::Hand.new(call)

  def dynamic?(call) = sent?(call) && own?(call.receiver) && computed?(call)

  def sent?(call) = Hashira::Analysis::Syntax::Message.new(call).dispatch? || SENDS.include?(call.name)

  def computed?(call) = !NAMED.include?(call.arguments&.arguments&.first.class)

  def own?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def said(text) = text.scan(TOKEN) { names << it }

  def built(parts)
    head, tail = Hashira::Coupling::Affixes.new(parts).to_a
    prefixes << head unless head.empty?
    suffixes << tail unless tail.empty?
  end
end
