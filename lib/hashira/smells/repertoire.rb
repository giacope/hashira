# frozen_string_literal: true

require "prism"

class Hashira::Smells::Repertoire
  class Entry
    def initialize(path, names, parents)
      @path = path
      @names = names
      @parents = parents
    end

    def answers = @parents.reduce(@names) { |all, parent| all | yield(parent) }

    def sealed?(&) = @parents.all?(&)

    def home = [@path, self]

    def suffixes = @path.each_index.map { [@path.drop(it).join("::"), self] }
  end

  FACTORIES = { "Struct" => :new, "Data" => :define, "Class" => :new }.freeze

  MIXINS = %i[include prepend].freeze

  NONE = Set.new.freeze

  def initialize(trees)
    @trees = trees
  end

  def of(segments) = gathered(segments.join("::"), Set.new, own(segments))

  def closed?(segments) = sealed?(segments.join("::"), Set.new, own(segments))

  private

  def own(segments) = homes.fetch(segments) { index.fetch(segments.join("::"), []) }

  def sealed?(name, seen, found = index.fetch(name, []))
    !seen.add?(name) || (found.any? && found.all? { |entry| entry.sealed? { sealed?(it, seen) } })
  end

  def gathered(name, seen, found = index.fetch(name, []))
    return NONE unless seen.add?(name)
    found.reduce(NONE) { |all, entry| all | entry.answers { gathered(it, seen) } }
  end

  def listed = @_listed ||= @trees.flat_map { entries(it) }

  def homes = @_homes ||= keyed(listed.map(&:home))

  def index = @_index ||= keyed(listed.flat_map(&:suffixes))

  def keyed(pairs) = pairs.group_by(&:first).transform_values { it.map(&:last) }

  def entries(tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk do |node, full|
      syntax = Hashira::Analysis::Syntax.new(node)
      found << entry(full, syntax.statements, heritage(node), instance(node))
      found.concat(syntax.constants.filter_map { built(full, it) if factory?(it.value) })
    end
    found
  end

  def built(full, constant)
    value = constant.value
    entry(full + [constant.name.to_s], [value, *Array(value.block&.body&.body)], Array(value.arguments&.arguments))
  end

  def instance(type)
    Hashira::Analysis::TypeWalk.new(type).sections.filter_map { |node, section| node.name unless lifted?(node, section) }
  end

  def lifted?(node, section) = node.receiver || section == :singleton

  def entry(path, statements, parents, defined = [])
    names = (statements.flat_map { declared(it) } + defined).to_set { it.to_s.delete_suffix("=") }
    Entry.new(path, names, parents.map { Hashira::Analysis::Syntax.new(it).segments.join("::") }.reject(&:empty?))
  end

  def heritage(type)
    mixed = Hashira::Analysis::Syntax.new(type).statements.grep(Prism::CallNode).select { MIXINS.include?(it.name) }
    [*(type.superclass if type.is_a?(Prism::ClassNode)), *mixed.flat_map { it.arguments.arguments }]
  end

  def declared(node)
    return [node.name] if node.is_a?(Prism::DefNode) && !node.receiver
    return [Hashira::Analysis::Syntax.new(node.new_name).text] if node.is_a?(Prism::AliasMethodNode)
    macro?(node) ? offered(node) : []
  end

  def macro?(node) = node.is_a?(Prism::CallNode) && (!node.receiver || factory?(node))

  def offered(call) = Array(call.arguments&.arguments).flat_map { symbol?(it) ? [text(it)] : declared(it) }

  def text(node) = Hashira::Analysis::Syntax.new(node).text

  def symbol?(node) = node.is_a?(Prism::SymbolNode)

  def factory?(value) = Hashira::Smells::Factory.new(value).made?(FACTORIES)
end
