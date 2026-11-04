# frozen_string_literal: true

class Hashira::Coupling::Unused
  def initialize(site, noun)
    @site = site
    @noun = noun
  end

  def to_h = { site: @site, noun: @noun }

  def phrase(package)
    "#{package} is never #{@noun == :method ? "called" : "referred to"} in the project (#{@site}). " \
      "Delete it, or name it in dead_code roots if code outside the project uses it."
  end
end
