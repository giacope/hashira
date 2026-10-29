# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Layering < Hashira::Coupling::Rule
  KIND = "layer_violation"

  Crossing =
    Data.define(:sighting, :source, :target, :to) do
      def outward? = source > target

      def ends = [sighting.holder, to]

      def site = sighting.site
    end

  Detail =
    Data.define(:inner, :outer, :cut, :refs, :leaning, :against) do
      def initialize(leaning: nil, against: nil, **) = super

      def to_h = super.compact
    end

  def list
    outward.group_by { [it.source, it.target] }.sort.map { |(inner, outer), group| entry(inner, outer, group) }
  end

  private

  def layers = project.layers

  def names = layers.names

  def outward = crossings.select(&:outward?)

  def crossings = @_crossings ||= graph.sightings.flat_map { crossing(it) }

  def crossing(sighting)
    source = layers.rank(sighting.file, sighting.from)
    return [] unless source
    placed(sighting).map { |target, to| Crossing.new(sighting:, source:, target:, to:) }
  end

  def placed(sighting) = (@_placed ||= {})[sighting.name] ||= place(sighting.path)

  def census = graph.census

  def place(path)
    ranks = census.files(path).filter_map { layers.rank(it, census.home(it)) }.uniq
    ranks.one? ? [[ranks.fetch(0), census.holder(path)]] : []
  end

  def entry(inner, outer, group)
    detail = Detail.new(inner: names[inner], outer: names[outer], cut: edges(group), refs: group.size, **leaning)
    finding(
      package: detail.inner, digest: "#{detail.inner} -> #{detail.outer}", evidence: sites(group), detail:,
      anchors: group.map(&:site).uniq
    )
  end

  def edges(group)
    weights = group.map(&:ends).tally
    weights.map { |(from, to), weight| weighed(from, to, weight) }.sort_by { it.values_at(:weight, :from, :to) }
  end

  def sites(group) = group.map { it.sighting.evidence }.uniq.sort

  def cut
    @_cut ||=
      Hashira::Coupling::Cut.new(
        names, crossings.map { [names[it.source], names[it.target]] }.tally.map { |ends, weight| [*ends, weight] },
        names.each_with_index.to_h
      )
  end

  def leaning
    against = cut.cost
    order = cut.order
    against < outward.size && layers.allows?(order) ? { leaning: order, against: } : {}
  end
end
