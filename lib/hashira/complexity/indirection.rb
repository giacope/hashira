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

  def findings
    @sites.filter_map do |file, site|
      next if helping.include?(site)
      entry = Hashira::Complexity::Entry.new(KIND, file, site)
      Hashira::Complexity::Trail.new(entry, helpers(site.family)).finding(limit)
    end
  end

  private

  def limit = @rules.threshold(KIND, THRESHOLD)

  def helping = @_helping ||= Set.new.compare_by_identity.merge(families.keys.flat_map { helpers(it).values })

  def helpers(family) = (@_helpers ||= {})[family] ||= chosen(family)

  def chosen(family) = defined(family).select { |name, site| helper?(family, name, site) }

  def helper?(family, name, site) = hidden.include?(site.node) && single?(family, name)

  def hidden = @_hidden ||= Hashira::Complexity::Sections.new(@trees).parted([PRIVATE])

  def defined(family) = families.fetch(family).select { it.node.is_a?(Prism::DefNode) }.to_h { [it.node.name, it] }

  def families = @_families ||= @sites.map(&:last).group_by(&:family)

  def single?(family, name) = calls(family)[name] == 1 && [named, received, borrowed].none? { it.include?(name) }

  def calls(family)
    (@_calls ||= {})[family] ||= families.fetch(family).flat_map { Hashira::Complexity::Calls.new(it.node).sent }.tally
  end

  def borrowed = @_borrowed ||= families.keys.flat_map { |family| calls(family).keys - defined(family).keys }.to_set

  def named = surveyed.first

  def received = surveyed.last

  def surveyed = @_surveyed ||= @trees.each_with_object([Set.new, Set.new]) { |tree, sets| survey(tree, *sets) }

  def survey(tree, symbols, receivers)
    nodes = Hashira::Analysis::NodeWalk.new(tree).collect
    symbols.merge(nodes.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }.map(&:to_sym))
    receivers.merge(nodes.grep(Prism::CallNode).reject { SELVES.include?(it.receiver.class) }.map(&:name))
  end
end
