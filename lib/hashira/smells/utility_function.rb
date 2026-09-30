# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  private

  def smelly? = subject.public? && !subject.polymorphic? && calls? && refs.ego.zero?

  def detail = { site:, owner: subject.host }

  def refs = Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def calls? = Hashira::Smells::Scope.inside(subject.node).any?(Prism::CallNode)
end
