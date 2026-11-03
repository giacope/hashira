# frozen_string_literal: true

class Hashira::Smells::Typeset
  def initialize(types)
    @types = types
  end

  def resolve(owner, segments) = candidates(owner, segments).lazy.select { it != owner && known?(it) }.first(1)

  def candidates(owner, segments) = segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }

  def known?(name) = names.include?(name)

  private

  def names = @_names ||= @types.to_set(&:to_s)

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end
end
