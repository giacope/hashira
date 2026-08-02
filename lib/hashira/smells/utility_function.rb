# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  private

  def smelly? = subject.public? && calls? && refs.ego.zero?

  def refs = Hashira::Smells::Refs.new(subject.node)

  def calls? = Hashira::Smells::Scope.inside(subject.node).any?(Prism::CallNode)

  def message
    "#{label} touches no instance state (#{site}). " \
      "Move it onto the object it serves, or make it a module function."
  end
end
