# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  PROTOCOL = { 0 => %i[hash inspect to_s], 1 => %i[== eql? equal? <=> === coerce] }.freeze

  private

  def smelly? = subject.host == :class && subject.public? && !subject.polymorphic? && !protocol? && calls? && stateless?

  def protocol? = PROTOCOL.fetch(arity, []).include?(subject.node.name)

  def arity = Array(subject.node.parameters&.requireds).size

  def stateless? = refs.ego.zero? && Hashira::Smells::Opaque.new(body).none?

  def detail = { site: }

  def refs = Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def calls? = body.any?(Prism::CallNode)

  def body = @_body ||= Hashira::Smells::Scope.new(subject.node).inside
end
