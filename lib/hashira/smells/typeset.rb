# frozen_string_literal: true

class Hashira::Smells::Typeset
  def initialize(types)
    @types = types
  end

  def resolve(owner, segments) = Array(candidates(owner, segments).find { it != owner && known?(it) })

  def candidates(owner, segments) = segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }

  def known?(name) = names.include?(name)

  def sweep(type) = swept.fetch(type) { swept[type] = type.accept(Hashira::Smells::Scope).sweep }

  private

  def names = @_names ||= @types.to_set(&:to_s)

  def swept = @_swept ||= {}.compare_by_identity

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end
end
