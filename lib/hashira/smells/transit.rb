# frozen_string_literal: true

require "prism"

class Hashira::Smells::Transit
  MAPPERS = %i[new from assign_attributes update!].freeze

  RENDERS = /\Arender/

  def initialize(definition, refs)
    @node = definition
    @refs = refs
  end

  def passing?(local)
    outlets = projections + forwards(local.name)
    @refs.reads(local).all? { |read| outlets.any? { fed?(it, read) } }
  end

  private

  def body = @_body ||= Hashira::Smells::Scope.inside(@node)

  def calls = @_calls ||= body.grep(Prism::CallNode)

  def projections = @_projections ||= (body.grep(Prism::HashNode) + keywords).flat_map { pairs(it) }

  def keywords = calls.select { mapper?(it.name) }.flat_map { arguments(it) }.grep(Prism::KeywordHashNode)

  def mapper?(name) = MAPPERS.include?(name) || RENDERS.match?(name)

  def forwards(name) = calls.map { values(it) }.select { whole?(it, name) }.flatten

  def whole?(values, name) = values.any? { it.is_a?(Prism::LocalVariableReadNode) && it.name == name }

  def values(call) = arguments(call).flat_map { it.is_a?(Prism::KeywordHashNode) ? pairs(it) : [it] }

  def pairs(hash) = hash.elements.grep(Prism::AssocNode).map(&:value)

  def arguments(call) = call.arguments&.arguments.to_a

  def fed?(outlet, read) = outlet.equal?(read) || (outlet.is_a?(Prism::CallNode) && fed?(outlet.receiver, read))
end
