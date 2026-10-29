# frozen_string_literal: true

require "prism"

class Hashira::Smells::ConcreteInheritance < Hashira::Smells::Check
  SHOWN = 3

  CORE = %w[Array Hash String Set].freeze

  BASED = /\ABase(?=[A-Z])/

  CONSTRUCTOR = :initialize

  CONCRETE = "Extract what they share into an abstract base both extend, or compose instead."

  class Core
    def initialize(site, parent)
      @site = site
      @parent = parent
    end

    def to_h = { site: @site, parent: @parent, home: @site, mode: :core }

    def phrase(package)
      "#{package} extends #{@parent}, a concrete core class (#{@site}). Keep one in a field and give the class " \
        "methods of its own: what it inherits (map, select, merge) answers a plain #{@parent}, not this class."
    end
  end

  class Lone
    def initialize(kind, package, core)
      @kind = kind
      @package = package
      @core = core
    end

    def finding(_parts, testimony) = testimony.finding(@kind, @package, @core)
  end

  class Kin
    def initialize(site, places, parent, mode)
      @site = site
      @places = places
      @parent = parent
      @mode = mode
    end

    def to_h
      fields = { site: @site, places: @places, parent: @parent, mode: @mode }
      @mode == :built ? fields.except(:mode) : fields
    end

    def phrase(package) = "#{package} #{said} (#{@site}). #{CONCRETE}"

    private

    def said
      one = @places == 1
      subclasses = one ? "a subclass" : "#{@places} subclasses"
      return "is a concrete class, and #{subclasses} override#{"s" if one} its working methods" if @mode == :overriding
      "is a concrete class the project also builds, and #{one ? "a subclass extends" : "#{subclasses} extend"} it"
    end
  end

  class Heir
    def initialize(kind, parent, home, mode)
      @kind = kind
      @parent = parent
      @home = home
      @mode = mode
    end

    def finding(parts, testimony)
      testimony.finding(@kind, @parent, Kin.new(@home, parts.size, @parent, @mode))
    end
  end

  def findings = []

  def members
    return [] unless smelly?
    core? ? [lone] : [heir]
  end

  private

  def lone
    member(:core, [label, site], Lone.new(kind, label, Core.new(site, base)), cited(evidence, site))
  end

  def heir
    told = testimony(["#{label} (#{site})"], evidence, [home, *anchors(site)])
    member(:heir, parent, Heir.new(kind, parent, home, mode), told)
  end

  def smelly? = core? || (parent && !abstract? && grounds?)

  def abstract? = family.abstract?(parent) || (strict? && BASED.match?(parent.split("::").last))

  def grounds? = framed? ? strict? && overrides.any? : built.any?

  def family = subject.family

  def parent = @_parent ||= family.parent(subject.subject)

  def core? = strict? && !parent && CORE.include?(base)

  def base
    written = subject.nodes.grep(Prism::ClassNode).filter_map(&:superclass).first
    Hashira::Analysis::Syntax.new(written).segments.join("::")
  end

  def framed? = family.framed?(parent)

  def built = family.built(parent)

  def overrides = @_overrides ||= subject.owned.select { working.include?(it.node.name) && !refusal?(it) }

  def working = @_working ||= family.definitions(parent).reject { refusal?(it) }.to_set { it.node.name } - [CONSTRUCTOR]

  def refusal?(method) = Hashira::Smells::Refusal.new(method.node).of.any?

  def mode = framed? ? :overriding : :built

  def home = family.home(parent)

  def evidence
    return ["#{subject.subject} < #{base} (#{site})"] if core?
    return overrides.map { "#{it.subject} (#{it.site})" } if mode == :overriding
    built.first(SHOWN).map { "#{parent}.new (#{it})" }
  end
end
