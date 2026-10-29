# frozen_string_literal: true

class Hashira::Complexity::Recursion
  LABEL = "recursion"

  def initialize(sites)
    @sites = sites
  end

  def increments(owner, node)
    cyclic.include?(owner.subject(node)) ? [Hashira::Complexity::Increment.new(node.location.start_line, 1, LABEL)] : []
  end

  private

  def cyclic = @_cyclic ||= components.select { looped?(it) }.flatten.to_set

  def components = Hashira::Complexity::Components.new(graph).to_a

  def looped?((first, *rest)) = rest.any? || graph.fetch(first).include?(first)

  def graph = @_graph ||= linked.transform_values { |callees| callees.select { linked.key?(it) } }

  def linked = @_linked ||= @sites.to_h { |_file, owner, node| [owner.subject(node), callees(owner, node)] }

  def callees(owner, node) = Hashira::Complexity::Calls.new(node).names.map { "#{owner.family(node)}#{it}" }
end
