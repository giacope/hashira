# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  private

  def smelly? = subject.host == :class && subject.public? && !subject.polymorphic? && calls? && refs.ego.zero?

  def detail = { site: }

  def refs = Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def calls? = Hashira::Smells::Scope.new(subject.node).inside.any?(Prism::CallNode)
end
