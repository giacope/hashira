# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Relay
  def initialize(cluster, defined, lead = Hashira::Duplication::Lead.new(Hashira::Duplication::Statements.new(cluster.canonical.to_a).to_a))
    @cluster = cluster
    @defined = defined
    @lead = lead
  end

  def relay? = @cluster.form.uniform? && (handing? || delegating?)

  private

  def handing?
    return false unless @lead.calls?(@defined)
    drifts = @cluster.variances.flat_map(&:drifts)
    passed = walk(*@lead.handed)
    drifts.intersect?(passed) && (drifts - passed - header).empty?
  end

  def delegating? = @cluster.to_a.combination(2).all? { delegates?(*it) }

  def delegates?(site, other)
    roots = site.to_a
    drifted = Hashira::Duplication::Variance.new(site, other).drifts
    roots.all? { drifted.intersect?(reach(it)) } && (drifted - roots.flat_map { delegated(it) }).empty?
  end

  def reach(root) = delegation(root).flat_map { [it, *Array(it.receiver).grep(Prism::InstanceVariableReadNode)] }

  def delegation(root)
    held = root.is_a?(Prism::DefNode) ? Hashira::Duplication::Statements.new([root]).to_a : []
    held.one? && held.first.is_a?(Prism::CallNode) && @defined.include?(held.first.name) ? held : []
  end

  def delegated(root)
    call = delegation(root).fetch(0)
    [root, *walk(root.parameters), call, call.receiver, *walk(call.arguments, call.block)]
  end

  def header = [*@cluster.canonical.to_a.grep(Prism::DefNode).flat_map { [it, *walk(it.parameters)] }, *@lead.named]

  def walk(*nodes) = nodes.compact.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }
end
