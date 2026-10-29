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
    @sites.filter_map do |file, owner, node|
      next if helping.include?(node)
      entry = Hashira::Complexity::Entry.new(KIND, file, owner.subject(node), node)
      Hashira::Complexity::Trail.new(entry, helpers(owner.family(node)), node).finding(limit)
    end
  end

  private

  def limit = @rules.threshold(KIND, THRESHOLD)

  def helping = @_helping ||= Set.new.compare_by_identity.merge(families.keys.flat_map { helpers(it).values })

  def helpers(family) = (@_helpers ||= {})[family] ||= chosen(family)

  def chosen(family) = defined(family).select { |name, node| helper?(family, name, node) }

  def helper?(family, name, node) = hidden.include?(node) && single?(family, name)

  def hidden = @_hidden ||= Hashira::Complexity::Sections.new(@trees).parted([PRIVATE])

  def defined(family)
    families.fetch(family).filter_map { |_file, _owner, node| [node.name, node] if node.is_a?(Prism::DefNode) }.to_h
  end

  def families = @_families ||= @sites.group_by { |_file, owner, node| owner.family(node) }

  def single?(family, name) = calls(family)[name] == 1 && [named, received, borrowed].none? { it.include?(name) }

  def calls(family)
    (@_calls ||= {})[family] ||=
      families.fetch(family).flat_map { |*, node| Hashira::Complexity::Calls.new(node).sent }.tally
  end

  def borrowed = @_borrowed ||= families.keys.flat_map { |family| calls(family).keys - defined(family).keys }.to_set

  def named = surveyed.fetch(0)

  def received = surveyed.fetch(1)

  def surveyed = @_surveyed ||= @trees.each_with_object([Set.new, Set.new]) { |tree, sets| survey(tree, *sets) }

  def survey(tree, symbols, receivers)
    nodes = Hashira::Analysis::NodeWalk.new(tree).collect
    symbols.merge(nodes.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }.map(&:to_sym))
    receivers.merge(nodes.grep(Prism::CallNode).reject { SELVES.include?(it.receiver.class) }.map(&:name))
  end
end
