# frozen_string_literal: true

class Hashira::Coupling::ConstantRegistry
  AMBIGUOUS = Object.new.freeze

  def initialize
    @origins = {}
  end

  attr_reader :origins

  def register(path, package)
    return if path.empty?
    claim(@origins, path, package)
  end

  def exact(path) = @origins[path.join("::")]

  def packages = (@origins.values.uniq - [AMBIGUOUS])

  private

  def claim(claims, path, package)
    key = path.join("::")
    claims[key] = claims.fetch(key, package) == package ? package : AMBIGUOUS
  end
end
