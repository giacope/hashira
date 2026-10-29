# frozen_string_literal: true

class Hashira::Smells::Doubt
  KIND = "nil_check"

  ADVICE = "Prefer a default, a null object, or polymorphism."

  ABSENCE = "Absence is the answer here, so ask for it: exists? instead of fetching a record to test for nil."

  OWNER = /[#.][^#.]+\z/

  LOCAL = %w[@ # .].freeze

  class Suspect
    def initialize(site, places, origin)
      @site = site
      @places = places
      @origin = origin
    end

    def to_h = { site: @site, places: @places, origin: @origin }.compact

    def phrase(package)
      checks = "#{Hashira::Prose::Count.new(@places, "method")} check#{"s" if @places == 1}"
      "#{package} may be nil, and #{checks} for it (#{@site}). #{ADVICE} Settle it where the nil is made."
    end
  end

  class Sighting
    def initialize(name, site, origin, ratings)
      @name = name
      @site = site
      @origin = origin
      @ratings = ratings
    end

    def finding(parts, testimony)
      testimony.finding(KIND, @name, Suspect.new(@site, parts.size, @origin), @ratings)
    end
  end

  def initialize(site, origin, sources)
    @site = site
    @origin = origin
    @sources = sources
  end

  def to_h = { site: @site, origin: @origin, sources: @sources }.compact

  def phrase(package) = "#{package} checks for nil (#{@site}). #{remedy}"

  def sightings(label, ratings)
    @sources.map do |name, site|
      named = name.start_with?(*LOCAL) ? label.sub(OWNER, "") + name : name
      [named, Sighting.new(named, site, @origin, ratings), ["#{label} (#{site})"]]
    end
  end

  private

  def remedy
    case @origin
    when :absence then ABSENCE
    when Array then optional
    else ADVICE
    end
  end

  def optional
    "#{Hashira::Prose::Quoted.new(@origin)} default#{"s" if @origin.one?} to nil, so callers may pass nothing and " \
      "the method is two in one: split it, or ask for a null object instead of nil."
  end
end
