# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::DeadCode < Hashira::Coupling::Rule
  KIND = "dead_code"

  def list
    surface = Hashira::Coupling::Surface.new(paths, graph.trees, graph.census)
    verdict(surface, Hashira::Coupling::Mentions.new(graph.trees, graph.roots)).sort_by(&:place).map { it.finding(KIND) }
  end

  private

  def verdict(surface, mentions)
    heritage = surface.heritage
    outside = Hashira::Coupling::Outside.new(project)
    marks = mentions.marks(graph.census, surface.openings)
    inquest = Hashira::Coupling::Inquest.new(
      mentions.spoken(outside.words, referenced), marks, anchors, hosting(surface, mentions, outside, heritage)
    )
    inquest.dead(surface.constants, surface.methods, heritage)
  end

  def hosting(surface, mentions, outside, heritage)
    openings = surface.openings
    registry = mentions.registry(heritage, surface.methods, openings)
    handover = mentions.handover(graph.census, outside.handed)
    Hashira::Coupling::Hosting.new(heritage, handover, openings.entered(anchors), registry)
  end

  def anchors = Hashira::Coupling::Anchors.new(Array(@rules.limit(KIND, "roots", [])), project)

  def referenced
    graph.sightings.each_with_object(Set.new) do |sighting, found|
      trail = [sighting.path, *graph.vias(sighting.path)]
      trail.each { |path| path.size.times { found << path.first(it + 1).join("::") } }
    end
  end
end
