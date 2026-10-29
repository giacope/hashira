# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Navigation < Hashira::Coupling::Rule
  KIND = "bidirectional_association"

  def list
    linked = declared.keys.select { declared.key?(it.reverse) }.map(&:sort).uniq
    linked.map { oriented(*it) }.group_by(&:first).sort.map { |parent, found| entry(parent, found.map(&:last)) }
  end

  private

  def declared = @_declared ||= edges.links.reject { it.to_a.uniq.one? }.group_by(&:to_a)

  def oriented(one, two) = owning?(two, one) && !owning?(one, two) ? [two, one] : [one, two]

  def owning?(from, to) = declared[[from, to]].any?(&:owning?)

  class Tangle
    def initialize(parent, children, guarantees, anchor)
      @parent = parent
      @children = children
      @guarantees = guarantees
      @anchor = anchor
    end

    def to_h = { parent: @parent, children: @children, guarantees: @guarantees }

    def phrase(_package)
      return paired(@children.fetch(0)) if @children.one?
      "#{@parent} is navigated both ways by #{@children.size} models, #{@children.join(", ")}: each declares an " \
        "association to the other (#{@anchor}), which ties them together. Drop #{@parent}'s side of each " \
        "and query the model where it is needed.#{carried}"
    end

    private

    def paired(child)
      "#{@parent} and #{child} each declare an association to the other (#{@anchor}) — navigating both " \
        "ways ties them together. Drop #{@parent}'s side and query #{child} where it is needed.#{carried}"
    end

    def carried
      return "" if @guarantees.empty?
      carries = @guarantees.map { it.split(": ", 2).last }.join("; ")
      " It carries #{carries}: hand that to an object above both, or to the foreign key, first."
    end
  end

  def entry(parent, children)
    links = ties(parent, children)
    anchors = links.map(&:anchor).uniq
    tangle = Tangle.new(parent, children, links.flat_map(&:pledge).uniq, anchors.first)
    sighted(parent, tangle, links.map(&:said).uniq, anchors)
  end

  def ties(parent, children)
    children.flat_map { declared[[parent, it]] }.sort + children.flat_map { declared[[it, parent]] }
  end
end
