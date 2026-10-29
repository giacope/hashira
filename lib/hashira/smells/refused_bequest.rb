# frozen_string_literal: true

class Hashira::Smells::RefusedBequest < Hashira::Smells::Check
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

  def members = refused.map { bequeathed(it, bequest[it.node.name]) }

  private

  def bequeathed(method, granted)
    home = granted.site
    told = testimony(["#{label} #{verb(method)} (#{method.site})"], [], [home, *anchors(site)])
    member(:bequest, granted.subject, Bequest.new(kind, granted.subject, home), told)
  end

  def family = subject.family

  def name = subject.subject

  def refused = @_refused ||= family.definitions(name).select { refuses?(it) }

  def refuses?(method)
    granted = bequest[method.node.name]
    granted && refusal(method) && !refusal(granted)
  end

  def refusal(method) = Hashira::Smells::Refusal.new(method.node).of

  def bequest
    @_bequest ||= family.ancestors(name).reverse.flat_map { family.definitions(it) }.to_h { [it.node.name, it] }
  end

  def verb(method) = VERBS.fetch(refusal(method))
end
