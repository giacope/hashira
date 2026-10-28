# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bags
  KIND = "data_class"

  Bag = Data.define(:name, :site, :fields)

  def initialize(types, family, methods)
    @types = types
    @family = family
    @methods = methods
  end

  def findings = bags.filter_map { finding(it) }

  private

  def bags
    (Hashira::Smells::Tuples.new(@types).bags + Hashira::Smells::Records.new(@types, @family).bags).uniq(&:name)
  end

  def finding(bag)
    used = Hashira::Smells::Readings.new(@methods).of(bag)
    return if used.empty?
    Hashira::Analysis::Finding.new(
      kind: KIND, package: bag.name, detail: { site: bag.site, fields: used.flat_map(&:fields).uniq, users: used.size },
      evidence: used.map(&:to_s), anchors: [bag.site, *used.map(&:spot)].uniq
    )
  end
end
