# frozen_string_literal: true

require_relative "contracts"
require_relative "rule"

class Hashira::Coupling::DeadCode < Hashira::Coupling::Rule
  KIND = "dead_code"

  include Hashira::Coupling::Contracts

  def list
    (constants + methods).sort_by(&:place).map do |member|
      noun = member.selector ? :method : :constant
      finding(package: member.name, detail: { site: member.site, noun: }, evidence: [], anchors: [member.site])
    end
  end

  private

  def surface = @_surface ||= Hashira::Coupling::Surface.new(project, graph.trees, graph.census)

  def mentions = @_mentions ||= Hashira::Coupling::Mentions.new(graph.trees, graph.roots).found

  def roots = @_roots ||= Array(@rules.limit(KIND, "roots", []))

  def constants
    dead = surface.constants.reject { live?(it) || holding?(it.path) }
    names = dead.to_set(&:path)
    dead.reject { |member| (1...member.path.size).any? { names.include?(member.path.first(it)) } }
  end

  def holding?(path)
    @_held ||= surface.constants.select { held?(it) }.map(&:path)
    @_held.any? { it.first(path.size) == path }
  end

  def held?(member)
    path = member.path
    rooted?(member) || registered?(path) || hosted?(path) || housed?(member) || loaded?(path)
  end

  def live?(member)
    path = member.path
    named?(path) || LEVELS.include?(path.last) || reflected?(member) || mentions.evaluated?(member.name)
  end

  def loaded?(path) = surface.types.fetch(path, []).any?(&:loads?)

  def named?(path) = used?(path) || mentioned?(path.last) || assembled?(path)

  def reflected?(member)
    @_reflection ||= Hashira::Coupling::Reflection.new(mentions.reflected, graph.census, surface.openings)
    @_reflection.reached?(member.path)
  end

  def housed?(member) = member.hosts.any? { hosted?(it) }

  def used?(path) = referenced.include?(path.join("::"))

  def referenced
    @_referenced ||=
      graph.sightings.each_with_object(Set.new) do |sighting, found|
        trail = [sighting.path, *graph.vias(sighting.path)]
        trail.each { |path| path.size.times { found << path.first(it + 1).join("::") } }
      end
  end

  def mentioned?(name) = mentions.names.include?(name) || outside.words.include?(name)

  def outside = @_outside ||= Hashira::Coupling::Outside.new(project)

  def registered?(path)
    @_inheriting ||= surface.methods.select { it.selector == "inherited" }.to_set(&:path)
    surface.ancestors(path).any? { @_inheriting.include?(it) || mentions.registries.include?(it.last) }
  end

  def methods
    surface.methods.reject { it.overrides || called?(it.selector) || rooted?(it) || framed?(it) || open?(it) }
  end

  def patch?(member) = [member.owner, *hosts(member.owner)].any? { foreign?(it) || surface.patched?(it) }

  def called?(name)
    bare = name.delete_suffix("=")
    HOOKS.include?(name) || protocol?(name) || mentioned?(name) || outside.words.include?(bare) || dynamic?(name)
  end

  def protocol?(name)
    Hashira::Analysis::UNIVERSAL.include?(name.to_sym) || Hashira::Analysis::VALUES.include?(name.to_sym)
  end

  def dynamic?(name) = mentions.prefixes.any? { name.start_with?(it) } || mentions.suffixes.any? { name.end_with?(it) }

  def assembled?(path)
    name = path.join("::")
    mentions.prefixes.any? { name.start_with?(it) } || mentions.suffixes.any? { path.last.end_with?(it) }
  end

  def framed?(member) = patch?(member) || (member.exposed ? hosted?(member.owner) : surface.backed?(member.owner))

  def hosted?(path) = hosted[path]

  def hosted = @_hosted ||= Hash.new { |found, path| found.store(path, false) || found[path] = settle(path) }

  def settle(path) = lineage(path).any? { surface.outside?(it) } || hosting?(path)

  def hosting?(path) = handover.told?(path) || hosts(path).any? { foreign?(it) || hosted?(it) || entered?(it) }

  def foreign?(host) = host == Hashira::Coupling::Handover::FOREIGN

  def hosts(path) = surface.mixers(path) + handover.hosts(path)

  def handover = @_handover ||= Hashira::Coupling::Handover.new(mentions.handed, graph.census, outside.handed)

  def entered?(path) = surface.types.fetch(path, []).any? { entry?(it.file) }

  def open?(member)
    @_opened ||= surface.openings.select { mentions.open.include?(it.node) }.to_set(&:path)
    lineage(member.owner).any? { @_opened.include?(it) }
  end

  def lineage(path) = [path, *surface.ancestors(path)]

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

  def entry?(file) = project.rails? && ENTRIES.include?(Hashira::Coupling::Stratum.new(absolute(file)).of)

  def absolute(file) = project.located(file)

  def api?(member) = (library? || engine_library?(member.file)) && member.exposed && owner_exposed?(member)

  def library? = !project.rails? && roots.empty?

  def engine_library?(file) = !project.engine.nil? && roots.empty? && shipped?(file)

  def shipped?(file) = absolute(file).delete_prefix("#{File.expand_path(project.home)}/").start_with?("lib/")

  def owner_exposed?(member) = exposure.fetch(member.owner, true)

  def exposure = @_exposure ||= surface.constants.to_h { [it.path, it.exposed] }
end
