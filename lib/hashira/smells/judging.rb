# frozen_string_literal: true

class Hashira::Smells::Judging
  def initialize(family, names, reaches, boundaries)
    @family = family
    @names = names
    @reaches = reaches
    @boundaries = boundaries
  end

  def checks(whole, kinds, rules) = kinds.map { it.build(whole, rules, @family) }

  def spread(whole) = Hashira::Smells::SpreadSwitch.new(whole, @names).findings

  def bags(types, methods) = Hashira::Smells::Bags.new(types, @family, methods, @names).findings

  def sprawl(methods, rules)
    Hashira::Smells::BoundarySprawl.new(methods, @boundaries.interpreted, rules, @reaches).findings
  end
end
