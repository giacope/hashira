# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::DeadCode < Hashira::Coupling::Rule
  KIND = "dead_code"

  def list
    trees = code.to_h
    roots = Hashira::Coupling::Autoload.new(project, trees).roots
    surface = Hashira::Coupling::Surface.new(paths, trees, lookup, roots)
    verdict(surface, Hashira::Coupling::Mentions.new(trees, roots)).sort_by(&:place).map { it.finding(KIND) }
  end

  private

  def verdict(surface, mentions)
    heritage = surface.heritage
    outside = Hashira::Coupling::Outside.new(project)
    marks = mentions.marks(lookup, surface.openings)
    inquest = Hashira::Coupling::Inquest.new(
      mentions.spoken(outside.words, referenced), marks, anchors, hosting(surface, mentions, outside, heritage)
    )
    inquest.dead(surface.constants, surface.methods, heritage)
  end

  def hosting(surface, mentions, outside, heritage)
    openings = surface.openings
    registry = mentions.registry(heritage, surface.methods, openings)
    handover = mentions.handover(lookup, outside.handed)
    Hashira::Coupling::Hosting.new(heritage, handover, openings.entered(anchors), registry)
  end

  def anchors = Hashira::Coupling::Anchors.new(Array(@rules.limit(KIND, "roots", [])), project)

  def referenced
    code.to_a.each_with_object(Set.new) do |sighting, found|
      sighting.trail(lookup).each { |path| path.size.times { found << path.first(it + 1).join("::") } }
    end
  end
end
