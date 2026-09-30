# frozen_string_literal: true

module Hashira::Coupling::Reach
  module_function

  def from(start, links) = spread(Set.new, [*links.fetch(start, [])], links)

  def spread(seen, frontier, links)
    while (node = frontier.shift)
      frontier.concat(links.fetch(node, []).to_a) if seen.add?(node)
    end
    seen
  end

  def invert(links)
    links.each_with_object({}) { |(from, tos), back| tos.each { (back[it] ||= []) << from } }
  end
end
