# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Relay
  def initialize(cluster, defined, lead = Hashira::Duplication::Lead.new(Hashira::Duplication::Statements.new(cluster.canonical.to_a).to_a))
    @cluster = cluster
    @defined = defined
    @lead = lead
  end

  def relay?
    return false unless @cluster.form.uniform? && @lead.calls?(@defined)
    drifts = @cluster.variances.flat_map(&:drifts)
    passed = walk(*@lead.handed)
    drifts.intersect?(passed) && (drifts - passed - header).empty?
  end

  private

  def header = [*canonical.to_a.grep(Prism::DefNode).flat_map { [it, *walk(it.parameters)] }, *@lead.named]

  def canonical = @cluster.canonical

  def walk(*nodes) = nodes.compact.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }
end
