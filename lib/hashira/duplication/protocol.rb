# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Protocol
  def initialize(cluster)
    @cluster = cluster
  end

  def protocol?
    @cluster.form.uniform? && @cluster.all? { lines?(it.to_a) } && names.uniq.one? && pairs.all? { own?(*it) }
  end

  private

  def names = @cluster.map { |site| site.to_a.map(&:name) }

  def lines?(roots) = roots.all? { line?(it) }

  def line?(root)
    held = Hashira::Duplication::Statements.new([root]).to_a
    root.is_a?(Prism::DefNode) && (root.name == :initialize || (held.one? && line(held.first).one?))
  end

  def line(node) = [node.location.start_line, node.location.end_line].uniq

  def pairs = @cluster.to_a.combination(2)

  def own?(site, other)
    drifts = Hashira::Duplication::Variance.new(site, other).drifts
    drifts.any? && site.to_a.all? { sent?(it, drifts) }
  end

  def sent?(root, drifts)
    calls = Hashira::Analysis::NodeWalk.new(root).collect.grep(Prism::CallNode)
    calls.empty? || drifts.intersect?(calls)
  end
end
