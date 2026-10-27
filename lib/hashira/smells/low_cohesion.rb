# frozen_string_literal: true

require "prism"

class Hashira::Smells::LowCohesion < Hashira::Smells::Check
  Piece = Data.define(:names, :fields, :calls)

  SIZE = 6

  MEMBERS = 2

  CONSTRUCTOR = :initialize

  FIELDS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  READS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableAndWriteNode
  ].freeze

  DELEGATORS = %i[def_delegator def_delegators def_instance_delegator def_instance_delegators].freeze

  SENDS = Hashira::Analysis::Syntax::SENDS

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  LISTING = :instance_variables

  STOCK = (Hashira::Smells::Readings::PERSISTENCE + Hashira::Analysis::UNIVERSAL.to_a).to_set.freeze

  PRESENTATION = /(?:Controller|Mailer|Job|Channel|Mailbox)(?:::[A-Z]\w*)?\z/

  PEEK = :instance_variable_get

  private

  def smelly? = subject.kind == :class && methods.size >= threshold(SIZE) && !framed? && groups.size > 1

  def framed? = strict? ? presented? : family.framed?(label)

  def presented? = [label, root].any? { PRESENTATION.match?(it) }

  def root = @_root ||= family.root(label)

  def methods = @_methods ||= subject.owned.reject { constructor?(it) }

  def constructor?(method) = method.node.name == CONSTRUCTOR

  def names = @_names ||= methods.to_set { it.node.name }

  def groups = @_groups ||= components.select { |members, fields| fields.any? && members.size >= MEMBERS }

  def components
    joined = pieces.reduce([]) { |found, piece| fuse(found, piece) }
    joined.map { |piece| [piece.names.select { names.include?(it) }, piece.fields.select { kept.include?(it) }] }
  end

  def pieces = (methods + mixed).map { piece(it.node.name, it.node, []) } + setup.map { piece(nil, it, inputs) }

  def mixed = @_mixed ||= family.mixed(subject.subject)

  def known = @_known ||= names | mixed.to_set { it.node.name }

  def piece(name, node, given)
    found = Hashira::Analysis::NodeWalk.new(node).collect
    shared = found.grep(Prism::LocalVariableReadNode).map(&:name) & given
    Piece.new([name], fields(found) + shared.map { :"(#{it})" }, calls(found))
  end

  def inputs = constructors.flat_map(&:parameters)

  def setup = constructors.flat_map { Hashira::Analysis::Syntax.new(it.node).statements.compact }

  def constructors = @_constructors ||= built(subject.owned).then { it.empty? ? bequeathed : it }

  def bequeathed = family.ancestors(subject.subject).lazy.map { built(family.definitions(it)) }.find(&:any?) || []

  def built(methods) = methods.select { constructor?(it) }

  def family = subject.family

  def fuse(found, piece)
    touching, apart = found.partition { linked?(it, piece) }
    apart + [(touching + [piece]).reduce { |all, part| merge(all, part) }]
  end

  def merge(left, right) = Piece.new(left.names + right.names, left.fields | right.fields, left.calls | right.calls)

  def linked?(left, right)
    left.fields.intersect?(right.fields) || left.calls.intersect?(right.names) || right.calls.intersect?(left.names)
  end

  def fields(found) = (touched(found) + attributed(found) + reached(found) + (peeks?(found) ? kept.to_a : [])).uniq

  def peeks?(found) = selves(found).any? { it.name == LISTING || (it.name == PEEK && computed?(it)) }

  def computed?(call) = call.arguments && !Hashira::Analysis::Syntax.new(call.arguments.arguments.first).word?

  def touched(found) = Hashira::Smells::Attributes.new(found).ivars(FIELDS)

  def attributed(found) = selves(found).filter_map { attributes[it.name.to_s.delete_suffix("=")] || column(it) }

  def column(call) = (bonds.field(call.name) if columned?(call))

  def columned?(call) = record? && call.variable_call? && !known.include?(call.name) && !STOCK.include?(call.name)

  def record? = Hashira::Smells::Records::RECORD.match?(root)

  def columns = sweep.grep(Prism::CallNode).filter_map { column(it) }.to_set

  def bonds = @_bonds ||= Hashira::Smells::Bonds.new(sweep)

  def calls(found) = (selves(found).map(&:name) + sent(found)).select { known.include?(it) }.uniq

  def selves(found) = found.grep(Prism::CallNode).select { inward?(it.receiver) }

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def sent(found)
    selves(found).select { SENDS.include?(it.name) }.flat_map { aimed(Array(it.arguments&.arguments).first) }
  end

  def reached(found) = sent(found).filter_map { attributes[it.to_s.delete_suffix("=")] }

  def aimed(name)
    return [] unless name
    return [Hashira::Analysis::Syntax.new(name).symbol] if Hashira::Analysis::Syntax.new(name).word?
    INTERPOLATED.include?(name.class) ? affixed(name) : tabled
  end

  def affixed(name)
    head, tail = Hashira::Coupling::Affixes.new(name.parts).to_a
    return writers.select { it.start_with?(head) } if written?(name)
    return tabled if head.empty? && tail.empty?
    names.select { it.start_with?(head) && it.end_with?(tail) }
  end

  def written?(name) = Hashira::Analysis::Syntax.new(name.parts.last).literal == "="

  def writers = @_writers ||= names.select { it.end_with?("=") } + Hashira::Smells::Attributes.new(sweep).writers

  def tabled = @_tabled ||= names.select { listed.include?(it) }

  def listed = sweep.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }.to_set(&:to_sym)

  def symbol(node) = Hashira::Analysis::Syntax.new(node).literal.to_s.to_sym

  def sweep = @_sweep ||= subject.sweep

  def attributes
    @_attributes ||= Hashira::Smells::Attributes.new(sweep).declared.to_h { [it, :"@#{it}"] }.merge(delegated)
  end

  def delegated
    Hashira::Smells::Attributes.new(sweep).macros(DELEGATORS).flat_map do |call|
      target, *names = Array(call.arguments&.arguments).map { symbol(it) }
      field = target.to_s.start_with?("@") ? target : :"@#{target}"
      names.reject(&:empty?).map { [it.to_s, field] }
    end.to_h
  end

  def kept = @_kept ||= sweep.select { READS.include?(it.class) }.to_set(&:name) | attributes.values | columns

  def detail = { site:, count: groups.size, size: methods.size }

  def evidence = groups.map { |members, fields| "#{members.join(", ")} (#{fields.sort.join(", ")})" }
end
