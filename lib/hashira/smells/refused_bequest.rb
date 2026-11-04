# frozen_string_literal: true

require_relative "lineal"

class Hashira::Smells::RefusedBequest < Hashira::Smells::Lineal
  VERBS = { raise: "raises", nothing: "does nothing" }.freeze

  OWNER = /[#.][^#.]+\z/

  class Bequeathed
    REFUSED = "Compose the parent instead of extending it, " \
      "or move the refused methods to the subclasses that want them."

    def initialize(site, places, parent)
      @site = site
      @places = places
      @parent = parent
    end

    def to_h = { site: @site, places: @places, parent: @parent }

    def phrase(package)
      refusers = @places == 1 ? "a subclass" : "#{@places} subclasses"
      "#{package} is overridden by #{refusers} only to raise or do nothing (#{@site}). #{REFUSED}"
    end
  end

  class Bequest
    def initialize(kind, method, home)
      @kind = kind
      @method = method
      @home = home
    end

    def finding(parts, testimony)
      testimony.finding(@kind, @method, Bequeathed.new(@home, parts.size, @method.sub(OWNER, "")))
    end
  end

  def findings = []

  def members = refused.map { bequeathed(it, bequest[selector(it)]) }

  private

  def bequeathed(method, granted)
    home = granted.spot.site
    told = testimony(["#{label} #{verb(method)} (#{method.spot.site})"], [], [home, *anchors(site)])
    member(:bequest, granted.to_s, Bequest.new(kind, granted.to_s, home), told)
  end

  def name = subject.to_s

  def refused = @_refused ||= family.inheritance.definitions(name).select { refuses?(it) }

  def refuses?(method)
    granted = bequest[selector(method)]
    granted && refusal(method).any? && refusal(granted).none?
  end

  def refusal(method) = method.accept(Hashira::Smells::Refusal).of

  def bequest
    @_bequest ||=
      family.tree.ancestors(name).reverse.flat_map { family.inheritance.definitions(it) }.to_h { [selector(it), it] }
  end

  def verb(method) = VERBS.fetch(refusal(method).fetch(0))
end
