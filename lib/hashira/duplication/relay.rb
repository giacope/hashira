# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Relay
  def initialize(cluster, defined)
    @cluster = cluster
    @defined = defined
  end

  def relay? = @cluster.uniform? && project? && drifts.intersect?(passed) && (drifts - passed - header).empty?

  private

  def project? = lead.calls?(@defined)

  def lead = @_lead ||= Hashira::Duplication::Lead.new(canonical.statements)

  def drifts = @_drifts ||= @cluster.others.flat_map { Hashira::Duplication::Variance.new(canonical, it).drifts }

  def passed = walk(*lead.handed)

  def header = [*canonical.roots.grep(Prism::DefNode).flat_map { [it, *walk(it.parameters)] }, *lead.named]

  def canonical = @cluster.canonical

  def walk(*nodes) = nodes.compact.flat_map { Hashira::Analysis::NodeWalk.collect(it) }
end
