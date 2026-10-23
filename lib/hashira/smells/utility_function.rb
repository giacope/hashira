# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  private

  def smelly? = subject.host == :class && subject.public? && !subject.polymorphic? && calls? && stateless?

  def stateless? = refs.ego.zero? && Hashira::Smells::Opaque.new(body).none?

  def detail = { site: }

  def refs = Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def calls? = body.any?(Prism::CallNode)

  def body = @_body ||= Hashira::Smells::Scope.new(subject.node).inside
end
