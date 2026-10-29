# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Layering < Hashira::Coupling::Rule
  KIND = "layer_violation"

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
    outward.group_by(&:to_a).sort.map { |(inner, outer), group| entry(inner, outer, group) }
  end

  private

  def names = @plan.layered(&:names)

  def outward = crossings.select(&:outward?)

  def crossings = @_crossings ||= code.to_a.flat_map { crossing(it) }

  def crossing(sighting)
    source = @plan.layered { sighting.rank(it) }
    return [] unless source
    placed(sighting).map { |target, to| sighting.cross(source, target, to) }
  end

  def placed(sighting)
    path = sighting.to_a
    (@_placed ||= {})[path] ||= place(path)
  end

  def place(path)
    ranks = code.files(path).filter_map { |file| @plan.layered { it.rank(file, code.home(file)) } }.uniq
    ranks.one? ? [[ranks.fetch(0), code.holder(path)]] : []
  end

  def entry(inner, outer, group)
    inside, outside = names.values_at(inner, outer)
    proof = Hashira::Analysis::Finding::Proof.new(sites(group), group.map(&:to_s).uniq)
    breach = Breach.new(inside, outside, Hashira::Coupling::Ties.new(weighed(group)), leanings)
    finding(between(inside, outside), breach, proof)
  end

  def weighed(group)
    weights = group.map(&:ends).tally
    weights.map { |(from, to), weight| [from, to, weight] }.sort_by { |from, to, weight| [weight, from, to] }
  end

  def sites(group) = group.map(&:evidence).uniq.sort

  def leanings
    found = cut
    against = found.cost
    order = found.order
    against < outward.size && @plan.layered { it.allows?(order) } ? [[order, against]] : []
  end

  def cut
    tallied = crossings.map { names.values_at(*it.to_a) }.tally.map { |ends, weight| [*ends, weight] }
    Hashira::Coupling::Cut.new(names, tallied, names.each_with_index.to_h)
  end
end
