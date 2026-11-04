# frozen_string_literal: true

class Hashira::Coupling::Said
  def initialize(site, label, holder)
    @site = site
    @label = label
    @holder = holder
  end

  def to_s = @site

  def evidence = "#{@site}: #{@label}"

  def ends(to) = [@holder, to]
end
