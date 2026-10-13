# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Indirection
  KIND = "indirection"

  THRESHOLD = 10

  SELVES = Hashira::Complexity::InlinedScore::SELVES

  def initialize(sites, trees, rules)
    @sites = sites
    @trees = trees
    @rules = rules
  end

  def findings = @sites.filter_map { |file, site| trail(file, site).finding(limit) unless helping.include?(site) }

  private

  def trail(file, site) = Hashira::Complexity::Trail.new(file, site, helpers(site.family).transform_values(&:node))

  def limit = @rules.threshold(KIND, THRESHOLD)

  def helping = @_helping ||= Set.new.compare_by_identity.merge(families.keys.flat_map { helpers(it).values })

  def helpers(family) = (@_helpers ||= {})[family] ||= defined(family).select { |name, _| single?(family, name) }

  def defined(family) = families.fetch(family).select { it.node.is_a?(Prism::DefNode) }.to_h { [it.node.name, it] }

  def families = @_families ||= @sites.map(&:last).group_by(&:family)

  def single?(family, name) = calls(family)[name] == 1 && [named, received, borrowed].none? { it.include?(name) }

  def calls(family) = (@_calls ||= {})[family] ||= families.fetch(family).flat_map { sent(it) }.tally

  def sent(site) = Hashira::Complexity::Calls.new(site.node).sent

  def borrowed = @_borrowed ||= families.keys.flat_map { |family| calls(family).keys - defined(family).keys }.to_set

  def named = @_named ||= nodes.grep(Prism::SymbolNode).to_set { it.unescaped.to_sym }

  def received = @_received ||= nodes.grep(Prism::CallNode).reject { SELVES.include?(it.receiver.class) }.to_set(&:name)

  def nodes = @_nodes ||= @trees.flat_map { Hashira::Analysis::NodeWalk.collect(it) }
end
