# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bags
  KIND = "data_class"

  class Bag
    def initialize(name:, site:, fields:)
      @name = name
      @site = site
      @fields = fields
    end

    def finding(readings)
      used = readings.of(self)
      return [] if used.empty?
      detail = { site: @site, fields: used.flat_map(&:fields).uniq, users: used.size }
      anchors = [@site, *used.map(&:spot)].uniq
      [Hashira::Analysis::Finding.new(kind: KIND, package: @name, detail:, evidence: used.map(&:to_s), anchors:)]
    end

    def outside?(owner) = ![@name, @name.sub(/::[^:]+\z/, "")].include?(owner)

    def typed?(types) = types == [@name]

    def reads?(name, common) = @fields ? @fields.include?(name) : !common.include?(name)

    def ==(other) = other.is_a?(Bag) && other.named?(@name)

    alias eql? ==

    def hash = [Bag, @name].hash

    protected

    def named?(name) = @name == name
  end

  def initialize(types, family, methods)
    @types = types
    @family = family
    @methods = methods
  end

  def findings = bags.flat_map { it.finding(Hashira::Smells::Readings.new(@methods)) }

  private

  def bags = (Hashira::Smells::Tuples.new(@types).bags + Hashira::Smells::Records.new(@types, @family).bags).uniq
end
