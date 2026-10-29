# frozen_string_literal: true

require "prism"

class Hashira::Smells::CallGroups
  def initialize(every, steadiness, bindings, enclosures)
    @every = every
    @steadiness = steadiness
    @bindings = bindings
    @enclosures = enclosures
  end

  def to_h
    calls = @every.select { @steadiness.steady?(it) }
    usual = calls.reject { plain?(it) || literal?(it) }.group_by { Hashira::Smells::Handle.new(it).to_s }
    whole = calls.select { literal?(it) }.group_by { it.slice.gsub(/\s+/, " ") }
    alike(usual).merge(alike(whole))
  end

  private

  def plain?(node) = !node.receiver && !node.arguments && !node.block.is_a?(Prism::BlockArgumentNode)

  def literal?(node) = node.block.is_a?(Prism::BlockNode)

  def alike(groups)
    repeated = groups.reject { |_text, nodes| nodes.one? }
    repeated.flat_map { |text, nodes| nodes.group_by { binding(it) }.map { |held, same| [[text, held], same] } }.to_h
  end

  def binding(node)
    lines = Hashira::Smells::Scope.new(node).inside.grep(Prism::SourceLineNode).map { it.location.start_line }
    [@bindings.free(node), @enclosures.of(node), lines.uniq]
  end
end
