# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Surface
  SUPERS = [Prism::SuperNode, Prism::ForwardingSuperNode].freeze

  HIDDEN = %i[private protected].freeze

  ALIASES = 3

  Member =
    Data.define(:name, :path, :owner, :site, :file, :exposed, :selector, :overrides) do
      def place = [file, site[/\d+\z/].to_i]

      def hosts = exposed ? [path[...-1]].reject(&:empty?) : []
    end

  def initialize(project, trees, census)
    @project = project
    @trees = trees
    @census = census
  end

  def openings = @_openings ||= @trees.flat_map { |file, tree| opened(file, tree) }

  def types = @_types ||= openings.group_by(&:path)

  def constants = @_constants ||= openings.flat_map { declared(it) }.group_by(&:path).values.map { merged(it) }

  def methods = @_methods ||= openings.flat_map { |opening| defined(opening) }

  def parents(path) = (@_parents ||= {})[path] ||= types.fetch(path, []).flat_map { heritage(it) }.uniq

  def ancestors(path, seen = Set[path])
    parents(path).each_with_object(Set.new) do |parent, all|
      next unless seen.add?(parent)
      all << parent
      all.merge(ancestors(parent, seen))
    end
  end

  def mixers(path) = (@_mixers ||= mixed).fetch(path, [])

  def outside?(path) = outside[path]

  def backed?(path) = [path, *mixers(path)].any? { outside?(it) }

  def patched?(path) = @census.abroad?(path)

  private

  def outside = @_outside ||= Hash.new { |found, path| found[path] = types.fetch(path, []).any? { hosted?(it) } }

  def opened(file, tree)
    found = []
    shown = @project.relative(file)
    Hashira::Analysis::TypeWalk.new(tree).walk(roots: @census.roots) do |node, full, stack, lexical|
      found << Hashira::Coupling::Opening.new(node:, full:, path: @census.strip(lexical), stack:, file: shown)
    end
    found
  end

  def declared(opening)
    hidden = opening.hidden
    [constant(opening, opening.node, opening.full, hidden: false), *written(opening, hidden)]
      .select { @census.owned?(it.path) }
  end

  def written(opening, hidden)
    Hashira::Analysis::Syntax.new(opening.node).constants.map do |node|
      name = node.name.to_s
      constant(opening, node, opening.full + [name], hidden: hidden.include?(name))
    end
  end

  def constant(opening, node, full, hidden:)
    Member.new(
      name: full.join("::"), path: @census.strip(full), site: opening.site(node), file: opening.file, exposed: !hidden,
      owner: nil, selector: nil, overrides: nil
    )
  end

  def merged(members) = members.min_by { [it.file, it.site] }.with(exposed: members.all?(&:exposed))

  def defined(opening)
    Hashira::Analysis::TypeWalk.new(opening.node).sections.map { |node, section| selector(opening, node, section) }
  end

  def selector(opening, node, section)
    singleton = node.receiver || section == :singleton
    Member.new(
      name: "#{opening.shown}#{singleton ? "." : "#"}#{node.name}", path: opening.owner, owner: opening.owner,
      site: opening.site(node), file: opening.file, exposed: exposed?(node, section), selector: node.name.to_s,
      overrides: super?(node)
    )
  end

  def exposed?(node, section) = !node.receiver.nil? || !HIDDEN.include?(section)

  def super?(node) = Hashira::Analysis::NodeWalk.new(node).collect.any? { SUPERS.include?(it.class) }

  def heritage(opening) = resolved(opening).filter_map(&:last)

  def resolved(opening) = opening.links.map { |node, nesting| [node, located(node, nesting)] }

  def mixed
    found = Hash.new { |hash, key| hash[key] = [] }
    openings.each { |opening| opening.included.each { |node, nesting| found[located(node, nesting)] << opening.path } }
    found
  end

  def located(node, nesting, depth = ALIASES)
    return unless Hashira::Analysis::Syntax.new(node).static?
    segments = Hashira::Analysis::Syntax.new(node).segments
    found = @census.locate(segments, Hashira::Analysis::Syntax.new(node).rooted? ? [] : nesting)
    aliased(found, depth) if found&.last == segments.last
  end

  def aliased(path, depth)
    value, nesting = aliases.of(path)
    return path unless value
    located(value, nesting, depth - 1) if depth.positive?
  end

  def aliases = @_aliases ||= Hashira::Coupling::Aliases.new(openings)

  def hosted?(opening) = resolved(opening).any? { |node, target| !target && foreign?(node) }

  def foreign?(node) = !Hashira::Analysis::CORE.include?(Hashira::Analysis::Syntax.new(node).origin)
end
