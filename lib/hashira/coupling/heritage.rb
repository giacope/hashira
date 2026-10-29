# frozen_string_literal: true

class Hashira::Coupling::Heritage
  ALIASES = 3

  def initialize(openings, census, aliases, builtins)
    @openings = openings
    @census = census
    @aliases = aliases
    @builtins = builtins
  end

  def lineage(path) = [path, *ancestors(path)]

  def mixers(path) = (@_mixers ||= mixed).fetch(path, [])

  def outside?(path) = outside[path]

  def patched?(path) = !path.empty? && !builtin?(path.first) && !@census.owned?(path)

  private

  def types = @_types ||= @openings.to_h

  def parents(path) = (@_parents ||= {})[path] ||= types.fetch(path, []).flat_map { heritage(it) }.uniq

  def ancestors(path, seen = Set[path])
    parents(path).each_with_object(Set.new) do |parent, all|
      next unless seen.add?(parent)
      all << parent
      all.merge(ancestors(parent, seen))
    end
  end

  def outside = @_outside ||= Hash.new { |found, path| found[path] = types.fetch(path, []).any? { hosted?(it) } }

  def heritage(relations) = resolved(relations).filter_map(&:last)

  def resolved(relations) = relations.to_a.map { |node, nesting| [node, located(node, nesting)] }

  def mixed
    found = Hash.new { |hash, key| hash[key] = [] }
    @openings.each do |path, relations|
      relations.included.each { |node, nesting| found[located(node, nesting)] << path }
    end
    found
  end

  def located(node, nesting, depth = ALIASES)
    return unless Hashira::Analysis::Syntax.new(node).static?
    segments = Hashira::Analysis::Syntax.new(node).segments
    found = @census.locate(segments, Hashira::Analysis::Syntax.new(node).rooted? ? [] : nesting)
    aliased(found, depth) if found&.last == segments.last
  end

  def aliased(path, depth)
    value, nesting = @aliases.of(path)
    return path unless value
    located(value, nesting, depth - 1) if depth.positive?
  end

  def hosted?(relations) = resolved(relations).any? { |node, target| !target && foreign?(node) }

  def foreign?(node) = !core?(Hashira::Analysis::Syntax::Message.new(node).origins)

  def core?(names) = names.any? { @builtins.core?(it) }

  def builtin?(root) = @builtins.core?(root) || @builtins.library?(root)
end
