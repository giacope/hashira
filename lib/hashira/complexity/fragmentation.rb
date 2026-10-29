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

  def findings
    limits = %w[helpers lines].zip([HELPERS, LINES]).map { |name, default| @rules.limit(KIND, name, default) }
    @sites.filter_map { |file, owner, node| shard(file, owner, node).finding(*limits) if entry?(node) }
  end

  private

  def shard(file, owner, node)
    entry = Hashira::Complexity::Entry.new(KIND, file, owner.subject(node), node)
    reach = Hashira::Complexity::Reach.new(node, helpers(owner.family(node)))
    Hashira::Complexity::Shard.new(entry, reach, @notes.fetch(file))
  end

  def helpers(family) = (@_helpers ||= {})[family] ||= table(family).select { |name, node| helper?(family, name, node) }

  def helper?(family, name, node) = !exposed.include?(node) && callers(family)[name] == 1 && !hook?(family, name)

  def hook?(family, name)
    owner = family.delete_suffix("#").delete_suffix(".").split("::")
    overrides.any? { |parent, names| owner.last(parent.size) == parent && names.include?(name) }
  end

  def overrides
    @_overrides ||=
      @trees.flat_map do |tree|
        Hashira::Analysis::TypeWalk.new(tree).to_enum(:walk).filter_map do |type, *|
          parent = Hashira::Analysis::Syntax.new(type.superclass).segments if type.is_a?(Prism::ClassNode)
          [parent, Hashira::Analysis::Syntax.new(type).direct.map(&:name)] unless Array(parent).empty?
        end
      end
  end

  def callers(family)
    (@_callers ||= {})[family] ||=
      table(family).values.flat_map { Hashira::Complexity::Calls.new(it).names - [it.name] }.tally
  end

  def entry?(node) = exposed.include?(node) && !HIDDEN.include?(node.name)

  def exposed = @_exposed ||= Hashira::Complexity::Sections.new(@trees).parted(OPEN)

  def table(family) = (@_tables ||= {})[family] ||= families.fetch(family).to_h { |*, node| [node.name, node] }

  def families
    @_families ||= @sites.select { |_file, _owner, node| node.is_a?(Prism::DefNode) }.group_by { |_file, owner, node| owner.family(node) }
  end
end
