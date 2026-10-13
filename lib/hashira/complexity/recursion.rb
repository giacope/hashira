# frozen_string_literal: true

require "tsort"

class Hashira::Complexity::Recursion
  def initialize(sites)
    @sites = sites
  end

  def increments(site) = site.recursion(cyclic)

  private

  def cyclic = @_cyclic ||= components.select { looped?(it) }.flatten.to_set

  def components = TSort.strongly_connected_components(graph.method(:each_key), method(:children))

  def children(name, &) = graph.fetch(name).each(&)

  def looped?((first, *rest)) = rest.any? || graph.fetch(first).include?(first)

  def graph = @_graph ||= @sites.to_h { [it.subject, it.callees & known] }

  def known = @_known ||= @sites.map(&:subject)
end
