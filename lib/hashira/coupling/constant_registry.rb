# frozen_string_literal: true

class Hashira::Coupling::ConstantRegistry
  AMBIGUOUS = Object.new.freeze

  def initialize
    @origins = {}
    @shorthand = {}
  end

  attr_reader :origins

  def register(path, package)
    return if path.empty?
    claim(@origins, path, package)
    (1...path.length).each { claim(@shorthand, path.drop(it), package) }
  end

  def package(path) = settle(anchored(path) || enclosing(path))

  def rooted(path) = settle(@origins[path.join("::")] || enclosing(path))

  def exact(path) = @origins[path.join("::")]

  def packages = (@origins.values.uniq - [AMBIGUOUS])

  private

  def claim(claims, path, package)
    key = path.join("::")
    claims[key] = claims.fetch(key, package) == package ? package : AMBIGUOUS
  end

  def settle(found) = (found unless found == AMBIGUOUS)

  def anchored(path)
    key = path.join("::")
    @origins[key] || @shorthand[key]
  end

  def enclosing(path)
    prefixes(path).filter_map { @origins[it] }.first
  end

  def prefixes(path)
    (path.length - 1).downto(1).map { path.first(it).join("::") }
  end
end
