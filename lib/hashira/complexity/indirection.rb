# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Indirection
  KIND = "indirection"

  THRESHOLD = 2

  PRIVATE = :private

  SELVES = [NilClass, Prism::SelfNode].freeze

  def initialize(sites, trees, rules)
    @sites = sites
    @trees = trees
    @rules = rules
  end

  def findings = @sites.filter_map { |file, site| trail(file, site).finding(limit) unless helping.include?(site) }

  private

  def trail(file, site) = Hashira::Complexity::Trail.new(entry(file, site), helpers(site.family))

  def entry(file, site) = Hashira::Complexity::Entry.new(KIND, file, site)

  def limit = @rules.threshold(KIND, THRESHOLD)

  def helping = @_helping ||= Set.new.compare_by_identity.merge(families.keys.flat_map { helpers(it).values })

  def helpers(family) = (@_helpers ||= {})[family] ||= chosen(family)

  def chosen(family) = defined(family).select { |name, site| helper?(family, name, site) }

  def helper?(family, name, site) = hidden.include?(site.node) && single?(family, name)

  def hidden = @_hidden ||= Hashira::Analysis::TypeWalk.parted(@trees, [PRIVATE])

  def defined(family) = families.fetch(family).select { it.node.is_a?(Prism::DefNode) }.to_h { [it.node.name, it] }

  def families = @_families ||= @sites.map(&:last).group_by(&:family)

  def single?(family, name) = calls(family)[name] == 1 && [named, received, borrowed].none? { it.include?(name) }

  def calls(family) = (@_calls ||= {})[family] ||= families.fetch(family).flat_map { sent(it) }.tally

  def sent(site) = Hashira::Complexity::Calls.new(site.node).sent

  def borrowed = @_borrowed ||= families.keys.flat_map { |family| calls(family).keys - defined(family).keys }.to_set

  def named = surveyed.first

  def received = surveyed.last

  def surveyed = @_surveyed ||= @trees.each_with_object([Set.new, Set.new]) { |tree, sets| survey(tree, *sets) }

  def survey(tree, symbols, receivers)
    nodes = Hashira::Analysis::NodeWalk.collect(tree)
    symbols.merge(Hashira::Analysis::Syntax.symbol_names(nodes).map(&:to_sym))
    receivers.merge(nodes.grep(Prism::CallNode).reject { SELVES.include?(it.receiver.class) }.map(&:name))
  end
end
