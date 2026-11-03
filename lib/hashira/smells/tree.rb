# frozen_string_literal: true

class Hashira::Smells::Tree
  def initialize(parents)
    @parents = parents
  end

  def parent(name) = @parents.fetch(name, [])

  def ancestors(name)
    found = [name]
    loop do
      above = parent(found.last) - found
      break if above.empty?
      found.concat(above)
    end
    found.drop(1)
  end

  def children(name) = @parents.filter_map { |child, above| child if above.include?(name) }

  def descendants(name)
    found = [name]
    found.each { found.concat(children(it) - found) }
    found.drop(1)
  end
end
