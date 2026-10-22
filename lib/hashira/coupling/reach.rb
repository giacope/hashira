# frozen_string_literal: true

class Hashira::Coupling::Reach
  def initialize(links)
    @links = links
  end

  def from(start)
    seen = Set.new
    frontier = [*@links.fetch(start, [])]
    while (node = frontier.shift)
      frontier.concat(@links.fetch(node, []).to_a) if seen.add?(node)
    end
    seen
  end

  def inverted = @links.each_with_object({}) { |(from, tos), back| tos.each { (back[it] ||= []) << from } }
end
