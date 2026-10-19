# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Layering < Hashira::Coupling::Rule
  KIND = "layer_violation"

  Crossing =
    Data.define(:sighting, :source, :target, :to) do
      def outward? = source > target

      def site = sighting.site
    end

  Detail =
    Data.define(:inner, :outer, :cut, :refs, :leaning, :against) do
      def initialize(leaning: nil, against: nil, **) = super

      def to_h = super.compact
    end

  def list
    return [] unless layers.any?
    outward.group_by { [it.source, it.target] }.sort.map { |(inner, outer), group| entry(inner, outer, group) }
  end

  private

  def layers = project.layers

  def names = layers.names

  def outward = crossings.select(&:outward?)

  def crossings = @_crossings ||= graph.sightings.filter_map { crossing(it) }

  def crossing(sighting)
    source = layers.rank(sighting.file, sighting.from)
    return unless source
    target, to = placed(sighting)
    Crossing.new(sighting:, source:, target:, to:) if target
  end

  def placed(sighting) = (@_placed ||= {})[sighting.name] ||= place(sighting.path)

  def census = graph.census

  def place(path)
    ranks = census.files(path).filter_map { layers.rank(it, census.home(it)) }.uniq
    [ranks.first, census.owner(path) || path.first] if ranks.one?
  end

  def entry(inner, outer, group)
    detail = Detail.new(inner: names[inner], outer: names[outer], cut: edges(group), refs: group.size, **leaning)
    finding(
      package: detail.inner, digest: "#{detail.inner} -> #{detail.outer}", evidence: sites(group), detail:,
      anchors: group.map(&:site).uniq
    )
  end

  def edges(group)
    weights = group.map { [it.sighting.from, it.to] }.tally
    weights.map { |(from, to), weight| weighed(from, to, weight) }.sort_by { it.values_at(:weight, :from, :to) }
  end

  def sites(group) = group.map { it.sighting.evidence }.uniq.sort

  def cut = @_cut ||= Hashira::Coupling::Cut.new(names, links, names.each_with_index.to_h)

  def leaning
    against = cut.cost
    against < declared ? { leaning: cut.order, against: } : {}
  end

  def declared = outward.size

  def links = @_links ||= crossings.map { [names[it.source], names[it.target]] }.tally.map { [*it.first, it.last] }
end
