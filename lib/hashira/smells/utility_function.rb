# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  private

  def smelly? = subject.public? && calls? && refs.ego.zero?

  def refs = Hashira::Smells::Refs.new(subject.node)

  def calls? = Hashira::Smells::Scope.inside(subject.node).any?(Prism::CallNode)
end
