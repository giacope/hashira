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

  private

  def smelly? = subject.kind == :class && methods.size >= threshold(SIZE) && !framed? && groups.size > 1

  def framed? = subject.family.framed?(subject.subject)

  def methods = @_methods ||= subject.owned.reject { constructor?(it) }

  def constructor?(method) = method.node.name == CONSTRUCTOR

  def names = @_names ||= methods.to_set { it.node.name }

  def groups = @_groups ||= components.select { |members, fields| fields.any? && members.size >= MEMBERS }

  def components
    joined = pieces.reduce([]) { |found, piece| fuse(found, piece) }
    joined.map { |piece| [piece.names.compact, piece.fields.select { kept.include?(it) }] }
  end

  def pieces = methods.map { |method| piece(method.node.name, method.node, []) } + setup.map { piece(nil, it, inputs) }

  def piece(name, node, given)
    found = Hashira::Analysis::NodeWalk.collect(node)
    shared = found.grep(Prism::LocalVariableReadNode).map(&:name) & given
    Piece.new([name], fields(found) + shared.map { :"(#{it})" }, calls(found))
  end

  def inputs = subject.owned.select { constructor?(it) }.flat_map(&:parameters)

  def setup
    subject.owned.select { constructor?(it) }.flat_map { Hashira::Analysis::Syntax.statements(it.node).compact }
  end

  def fuse(found, piece)
    touching, apart = found.partition { linked?(it, piece) }
    apart + [(touching + [piece]).reduce { |all, part| merge(all, part) }]
  end

  def merge(left, right) = Piece.new(left.names + right.names, left.fields | right.fields, left.calls | right.calls)

  def linked?(left, right)
    left.fields.intersect?(right.fields) || left.calls.intersect?(right.names) || right.calls.intersect?(left.names)
  end

  def fields(found) = (touched(found) + attributed(found)).uniq

  def touched(found) = Hashira::Smells::Attributes.ivars(found, FIELDS)

  def attributed(found) = selves(found).filter_map { attributes[it.name.to_s.delete_suffix("=")] }

  def calls(found) = (selves(found).map(&:name) + sent(found)).select { names.include?(it) }.uniq

  def selves(found) = found.grep(Prism::CallNode).select { inward?(it.receiver) }

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def sent(found)
    selves(found).select { SENDS.include?(it.name) }.filter_map { symbol(Array(it.arguments&.arguments).first) }
  end

  def symbol(node) = (node.unescaped.to_sym if node.is_a?(Prism::SymbolNode))

  def sweep = @_sweep ||= subject.sweep

  def attributes
    @_attributes ||= Hashira::Smells::Attributes.declared(sweep).to_h { [it, :"@#{it}"] }.merge(delegated)
  end

  def delegated
    Hashira::Smells::Attributes.macros(sweep, DELEGATORS).flat_map do |call|
      target, *names = Array(call.arguments&.arguments).map { symbol(it) }
      field = target.to_s.start_with?("@") ? target : :"@#{target}"
      names.compact.map { [it.to_s, field] }
    end.to_h
  end

  def kept = @_kept ||= sweep.select { READS.include?(it.class) }.to_set(&:name) | attributes.values

  def detail = { site:, count: groups.size, size: methods.size }

  def evidence = groups.map { |members, fields| "#{members.join(", ")} (#{fields.sort.join(", ")})" }
end
