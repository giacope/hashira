# frozen_string_literal: true

class Hashira::Complexity::Recursion
  def initialize(sites)
    @sites = sites
  end

  def increments(site) = site.recursion(cyclic)

  private

  def cyclic = @_cyclic ||= components.select { looped?(it) }.flatten.to_set

  def components = Hashira::Complexity::Components.new(graph).to_a

  def looped?((first, *rest)) = rest.any? || graph.fetch(first).include?(first)

  def graph = @_graph ||= @sites.to_h { [it.subject, it.callees.select { known.include?(it) }] }

  def known = @_known ||= @sites.to_set(&:subject)
end
