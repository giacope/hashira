# frozen_string_literal: true

class Hashira::Coupling::Link
  OWNING = %i[has_many has_one has_and_belongs_to_many].freeze

  def initialize(ends, site, macro, pledges)
    @ends = ends
    @site = site
    @macro = macro
    @pledges = pledges
  end

  def to_a = @ends

  def <=>(other) = line <=> other.line

  def owning? = OWNING.include?(@macro.to_sym)

  def anchor = @site.scan(/\A.+?:\d+/).fetch(0)

  def said = @site.sub(": ", ": #{@macro} ")

  def pledge = @pledges.values_at(@site).compact

  protected

  def line = @site[/:(\d+):/, 1].to_i
end
