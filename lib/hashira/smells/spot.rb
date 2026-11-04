# frozen_string_literal: true

class Hashira::Smells::Spot
  def initialize(site, said, advice)
    @site = site
    @said = said
    @advice = advice
  end

  def to_h = { site: @site }

  def phrase(package) = "#{package} #{@said} (#{@site}). #{@advice}"
end
