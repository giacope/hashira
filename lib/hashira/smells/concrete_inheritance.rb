# frozen_string_literal: true

class Hashira::Smells::ConcreteInheritance < Hashira::Smells::Check
  SHOWN = 3

  private

  def smelly? = parent && !family.framed?(parent) && !family.abstract?(parent) && built.any?

  def family = subject.family

  def parent = @_parent ||= family.parent(subject.subject)

  def built = family.built(parent)

  def detail = { site:, parent: }

  def evidence = built.first(SHOWN).map { "#{parent}.new (#{it})" }
end
