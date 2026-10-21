# frozen_string_literal: true

require_relative "contracts"
require_relative "rule"

class Hashira::Coupling::DeadCode < Hashira::Coupling::Rule
  KIND = "dead_code"

  include Hashira::Coupling::Contracts

  def list = (constants + methods).sort_by(&:place).map { entry(it) }

  private

  def surface = @_surface ||= Hashira::Coupling::Surface.new(project, graph.trees, graph.census)

  def mentions = @_mentions ||= Hashira::Coupling::Mentions.new(graph.trees).found

  def roots = @_roots ||= Array(@rules.limit(KIND, "roots", []))

  def constants
    dead = surface.constants.reject { live?(it) || holding?(it.path) }
    names = dead.to_set(&:path)
    dead.reject { |member| (1...member.path.size).any? { names.include?(member.path.first(it)) } }
  end

  def holding?(path) = held.any? { it.first(path.size) == path }

  def held = @_held ||= surface.constants.select { held?(it) }.map(&:path)

  def held?(member) = rooted?(member) || registered?(member.path) || hosted?(member.path) || housed?(member)

  def live?(member)
    path = member.path
    named?(path) || LEVELS.include?(path.last) || rooted?(member) || framework?(member)
  end

  def named?(path) = used?(path) || mentioned?(path.last) || assembled?(path)

  def framework?(member) = registered?(member.path) || hosted?(member.path) || housed?(member) || reflected?(member)

  def reflected?(member) = reflection.reached?(member.path)

  def reflection
    @_reflection ||= Hashira::Coupling::Reflection.new(mentions.reflected, graph.census, surface.openings)
  end

  def housed?(member) = member.hosts.any? { hosted?(it) }

  def used?(path) = referenced.include?(path.join("::"))

  def referenced
    @_referenced ||=
      graph.sightings.each_with_object(Set.new) do |sighting, found|
        trail(sighting.path).each { |path| path.size.times { found << path.first(it + 1).join("::") } }
      end
  end

  def trail(path) = [path, *graph.census.vias(path)]

  def mentioned?(name) = mentions.names.include?(name) || words.include?(name)

  def words = outside.words

  def outside = @_outside ||= Hashira::Coupling::Outside.new(project)

  def registered?(path)
    surface.ancestors(path).any? { inheriting.include?(it) || mentions.registries.include?(it.last) }
  end

  def inheriting = @_inheriting ||= surface.methods.select { it.selector == "inherited" }.to_set(&:path)

  def methods
    surface.methods.reject { it.overrides || called?(it.selector) || rooted?(it) || framed?(it) || open?(it) }
  end

  def called?(name)
    bare = name.delete_suffix("=")
    HOOKS.include?(name) || protocol?(name) || mentioned?(name) || words.include?(bare) || dynamic?(name)
  end

  def protocol?(name)
    Hashira::Analysis::UNIVERSAL.include?(name.to_sym) || Hashira::Analysis::VALUES.include?(name.to_sym)
  end

  def dynamic?(name) = mentions.prefixes.any? { name.start_with?(it) } || mentions.suffixes.any? { name.end_with?(it) }

  def assembled?(path)
    name = path.join("::")
    mentions.prefixes.any? { name.start_with?(it) } || mentions.suffixes.any? { path.last.end_with?(it) }
  end

  def framed?(member) = member.exposed ? hosted?(member.owner) : surface.outside?(member.owner)

  def hosted?(path) = (@_hosted ||= {}).fetch(path) { settle(path) }

  def settle(path)
    @_hosted[path] = false
    @_hosted[path] = lineage(path).any? { surface.outside?(it) } || hosting?(path)
  end

  def hosting?(path) = handover.told?(path) || hosts(path).any? { foreign?(it) || hosted?(it) || entered?(it) }

  def hosts(path) = surface.mixers(path) + handover.hosts(path)

  def foreign?(host) = host == Hashira::Coupling::Handover::FOREIGN

  def handover = @_handover ||= Hashira::Coupling::Handover.new(mentions.handed, graph.census, outside.handed)

  def entered?(path) = surface.types.fetch(path, []).any? { entry?(it.file) }

  def open?(member) = lineage(member.owner).any? { opened.include?(it) }

  def lineage(path) = [path, *surface.ancestors(path)]

  def opened = @_opened ||= surface.openings.select { mentions.open.include?(it.node) }.to_set(&:path)

  def rooted?(member) = declared?(member) || entry?(member.file) || api?(member)

  def declared?(member) = roots.any? { root?(it, member) }

  def root?(root, member)
    return within?(member.file, root) if root.include?("/") || root.end_with?(".rb")
    name = member.name
    name == root || %w[:: # .].any? { name.start_with?("#{root}#{it}") }
  end

  def within?(file, root)
    place = File.expand_path(root, project.home)
    path = absolute(file)
    path == place || path.start_with?("#{place}/")
  end

  def entry?(file) = project.rails? && ENTRIES.include?(Hashira::Coupling::Stratum.of(absolute(file)))

  def absolute(file) = File.expand_path(file, project.directories.then { it.one? ? it.first : "." })

  def api?(member) = library? && member.exposed && owner_exposed?(member)

  def library? = !project.rails? && roots.empty?

  def owner_exposed?(member) = exposure.fetch(member.owner, true)

  def exposure = @_exposure ||= surface.constants.to_h { [it.path, it.exposed] }

  def entry(member)
    noun = member.selector ? :method : :constant
    finding(package: member.name, detail: { site: member.site, noun: }, evidence: [], anchors: [member.site])
  end
end
