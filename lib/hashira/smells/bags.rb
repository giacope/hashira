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
      detail = Hashira::Smells::DataClass::Holding.new(@site, used.flat_map(&:fields).uniq, [used.size])
      proof = Hashira::Analysis::Finding::Proof.new(used.map(&:to_s), [@site, *used.map(&:spot)].uniq)
      [Hashira::Analysis::Finding.new(KIND, Hashira::Analysis::Finding::Name.new(@name), detail, proof)]
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

  def initialize(types, family, methods, names)
    @types = types
    @family = family
    @methods = methods
    @names = names
  end

  def findings = bags.flat_map { it.finding(Hashira::Smells::Readings.new(@methods, @names)) }

  private

  def bags = (Hashira::Smells::Tuples.new(@types).bags + Hashira::Smells::Records.new(@types, @family).bags).uniq
end
