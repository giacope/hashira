# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Fragmentation
  KIND = "fragmentation"

  HELPERS = 4

  LINES = 3.5

  OPEN = %i[public module_function singleton].freeze

  HIDDEN = %i[initialize initialize_copy initialize_dup initialize_clone respond_to_missing? method_missing].freeze

  def initialize(sites, notes, trees, rules)
    @sites = sites
    @notes = notes
    @trees = trees
    @rules = rules
  end

  def findings = @sites.filter_map { |file, site| shard(file, site).finding(*limits) if entry?(site) }

  private

  def limits = %w[helpers lines].zip([HELPERS, LINES]).map { |name, default| @rules.limit(KIND, name, default) }

  def shard(file, site) = Hashira::Complexity::Shard.new(entry(file, site), reach(site), @notes.fetch(file))

  def entry(file, site) = Hashira::Complexity::Entry.new(KIND, file, site)

  def reach(site) = Hashira::Complexity::Reach.new(site, helpers(site.family))

  def helpers(family) = (@_helpers ||= {})[family] ||= table(family).select { |name, site| helper?(family, name, site) }

  def helper?(family, name, site) = !exposed.include?(site.node) && callers(family)[name] == 1

  def callers(family) = (@_callers ||= {})[family] ||= table(family).values.flat_map { called(it) }.tally

  def called(site) = Hashira::Complexity::Calls.new(site.node).names - [site.node.name]

  def entry?(site) = exposed.include?(site.node) && !HIDDEN.include?(site.node.name)

  def exposed = @_exposed ||= Hashira::Complexity::Sections.new(@trees).parted(OPEN)

  def table(family) = (@_tables ||= {})[family] ||= families.fetch(family).to_h { [it.node.name, it] }

  def families = @_families ||= @sites.map(&:last).select { it.node.is_a?(Prism::DefNode) }.group_by(&:family)
end
