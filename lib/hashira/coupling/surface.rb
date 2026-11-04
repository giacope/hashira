# frozen_string_literal: true

class Hashira::Coupling::Surface
  def initialize(paths, trees, lookup, roots)
    @paths = paths
    @trees = trees
    @lookup = lookup
    @roots = roots
  end

  def constants
    @_constants ||= opened.flat_map { it.declared(@lookup) }.group_by(&:to_a).values.map { it.drop(1).sum(it.first) }
  end

  def methods = @_methods ||= opened.flat_map(&:defined)

  def heritage(builtins = Hashira::Runtime::Builtins.new)
    Hashira::Coupling::Heritage.new(openings, @lookup, Hashira::Coupling::Aliases.new(openings), builtins)
  end

  def openings = Hashira::Coupling::Openings.new(rows)

  private

  def rows = @_rows ||= @trees.flat_map { |file, tree| walked(file, tree) }

  def opened = rows.map { Hashira::Coupling::Opening.new(*it) }

  def walked(file, tree)
    found = []
    shown = @paths.relative(file)
    Hashira::Analysis::TypeWalk.new(tree).walk(roots: @roots) do |node, full, stack, lexical|
      found << [node, stack + [full], @lookup.strip(lexical), shown]
    end
    found
  end
end
