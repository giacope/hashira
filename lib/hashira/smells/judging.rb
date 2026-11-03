# frozen_string_literal: true

class Hashira::Smells::Judging
  def initialize(family, names, reaches, boundaries)
    @family = family
    @names = names
    @reaches = reaches
    @boundaries = boundaries
  end

  def wholes(types) = types.group_by(&:name).values.map { Hashira::Smells::Whole.new(openings: it, family: @family) }

  def spread(whole) = Hashira::Smells::SpreadSwitch.new(whole, @names).findings

  def bags(types, methods) = Hashira::Smells::Bags.new(types, @family, methods, @names).findings

  def sprawl(methods, rules)
    Hashira::Smells::BoundarySprawl.new(methods, @boundaries.interpreted, rules, @reaches).findings
  end
end
