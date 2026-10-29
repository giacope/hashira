# frozen_string_literal: true

class Hashira::Coupling::Metric
  def initialize(types, afferent, efferent)
    @types = types
    @afferent = afferent
    @efferent = efferent
  end

  def to_h = { tc: @types, ca: @afferent, ce: @efferent }.merge(i: (instability unless isolated?))

  def to_a = [@types, @afferent, @efferent, isolated? ? "—" : shown]

  def <=>(other) = order <=> other.order

  def -(other) = (level - other.level).round(2)

  def instability
    total = @efferent + @afferent
    total.zero? ? 0.0 : @efferent.fdiv(total)
  end

  def measured?(least) = degree >= least

  def leaf? = @types <= 1 && @efferent.zero? && @afferent <= 1

  protected

  def order = [isolated? ? 1 : 0, instability]

  def level = shown.to_f

  private

  def degree = @efferent + @afferent

  def isolated? = degree.zero?

  def shown = format("%.2f", instability)
end
