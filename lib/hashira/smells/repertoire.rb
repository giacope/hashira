# frozen_string_literal: true

require "prism"

class Hashira::Smells::Repertoire
  Entry =
    Data.define(:path, :names, :parents) do
      def answers = parents.reduce(names) { |all, parent| all | yield(parent) }
    end

  FACTORIES = { "Struct" => :new, "Data" => :define, "Class" => :new }.freeze

  MIXINS = %i[include prepend].freeze

  NONE = Set.new.freeze

  def initialize(trees)
    @trees = trees
  end

  def of(segments) = gathered(segments.join("::"), Set.new)

  private

  def gathered(name, seen)
    return NONE unless seen.add?(name)
    index.fetch(name, []).reduce(NONE) { |all, entry| all | entry.answers { gathered(it, seen) } }
  end

  def index
    @_index ||=
      @trees.flat_map { entries(it) }.flat_map { filed(it) }.group_by(&:first).transform_values { it.map(&:last) }
  end

  def filed(entry) = entry.path.each_index.map { [entry.path.drop(it).join("::"), entry] }

  def entries(tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk { |node, full| found.push(own(node, full), *constants(node, full)) }
    found
  end

  def own(type, full) = entry(full, Hashira::Analysis::Syntax.new(type).statements, heritage(type))

  def constants(type, full)
    Hashira::Analysis::Syntax.new(type).constants.filter_map { built(full, it) if factory?(it.value) }
  end

  def built(full, constant)
    value = constant.value
    entry(full + [constant.name.to_s], [value, *Array(value.block&.body&.body)], Array(value.arguments&.arguments))
  end

  def entry(path, statements, parents)
    names = statements.flat_map { declared(it) }.to_set { it.to_s.delete_suffix("=") }
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

  def offered(call) = Array(call.arguments&.arguments).flat_map { symbol(it) || declared(it) }

  def symbol(node) = ([Hashira::Analysis::Syntax.new(node).text] if node.is_a?(Prism::SymbolNode))

  def factory?(value) = Hashira::Smells::Factory.new(value).made?(FACTORIES)
end
