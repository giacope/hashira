# frozen_string_literal: true

class Hashira::Smells::Births
  def initialize(openings, sites)
    @openings = openings
    @sites = sites
  end

  def built(name) = @sites.fetch(name, [])

  def home(name) = Hashira::Smells::Footprint.new(@openings.fetch(name)).site
end
