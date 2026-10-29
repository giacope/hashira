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

  class Breach
    def initialize(inner, outer, ties, leanings)
      @inner = inner
      @outer = outer
      @ties = ties
      @leanings = leanings
    end

    def to_h
      leaning, against = @leanings.fetch(0, [])
      { inner: @inner, outer: @outer, cut: @ties.to_a, refs: @ties.total, leaning:, against: }.compact
    end

    def phrase(_package)
      "#{@inner} depends on #{@outer}, an outer layer, through #{count(@ties.total, "ref")} — " \
        "a layer may depend only on the layers declared inside it. Cut #{@ties.outward}.#{leaning}"
    end

    private

    def count(number, noun) = Hashira::Prose::Count.new(number, noun).to_s

    def leaning
      @leanings.map do |order, against|
        left = against.zero? ? "no ref" : "only #{count(against, "ref")}"
        " The code leans another way: layered #{order.join(", ")}, #{left} would point outward — " \
          "check the declared order."
      end.join
    end
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
    inside, outside = names.values_at(inner, outer)
    proof = Hashira::Analysis::Finding::Proof.new(sites(group), group.map(&:site).uniq)
    breach = Breach.new(inside, outside, Hashira::Coupling::Ties.new(edges(group)), leanings)
    finding(between(inside, outside), breach, proof)
  end

  def edges(group)
    weights = group.map(&:ends).tally
    weights.map { |(from, to), weight| [from, to, weight] }.sort_by { |from, to, weight| [weight, from, to] }
  end

  def sites(group) = group.map { it.sighting.evidence }.uniq.sort

  def cut
    @_cut ||=
      Hashira::Coupling::Cut.new(
        names, crossings.map { [names[it.source], names[it.target]] }.tally.map { |ends, weight| [*ends, weight] },
        names.each_with_index.to_h
      )
  end

  def leanings
    against = cut.cost
    order = cut.order
    against < outward.size && layers.allows?(order) ? [[order, against]] : []
  end
end
