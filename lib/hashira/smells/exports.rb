# frozen_string_literal: true

require "prism"

class Hashira::Smells::Exports
  DEPTH = 4

  NESTED = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode, Prism::DefNode].freeze

  PATHS = [Prism::ConstantReadNode, Prism::ConstantPathNode].freeze

  def initialize(trees, ownership)
    @trees = trees
    @ownership = ownership
  end

  def origin(segments, owner) = DEPTH.times.reduce(segments) { |path, _| hop(path, owner) }

  private

  def hop(path, owner)
    size, home = path.size.downto(1).lazy.map { [it, @ownership.place(path.first(it), owner)] }.find(&:last)
    source = table[home]
    source ? source + path.drop(size) : path
  end

  def table
    @_table ||= @trees.flat_map do |tree|
      Hashira::Analysis::TypeWalk.new(tree).to_enum(:walk).flat_map do |node, full|
        name = full.join("::")
        copies(node, name) + aliases(node, name)
      end
    end.to_h
  end

  def copies(node, name)
    shallow(node.body).grep(Prism::CallNode).filter_map { copied(it) }.map { [name, resolved(it, name)] }
  end

  def aliases(node, name)
    constants = Hashira::Analysis::Syntax.new(node).constants.select { PATHS.include?(it.value.class) }
    constants.map { ["#{name}::#{it.name}", resolved(Hashira::Analysis::Syntax.new(it.value).segments, name)] }
  end

  def copied(call)
    name, value = Array(call.arguments&.arguments)
    copy = call.name == :const_set && !call.receiver && fetched?(value, name)
    Hashira::Analysis::Syntax.new(value.receiver).segments if copy
  end

  def fetched?(value, name)
    value.is_a?(Prism::CallNode) && value.name == :const_get && PATHS.include?(value.receiver.class) &&
      Array(value.arguments&.arguments).map(&:slice) == [name.slice]
  end

  def resolved(segments, name) = @ownership.place(segments, name)&.split("::") || segments

  def shallow(node)
    return [] if node.nil? || NESTED.include?(node.class)
    [node, *node.compact_child_nodes.flat_map { shallow(it) }]
  end
end
