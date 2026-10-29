# frozen_string_literal: true

require_relative "placement"

class Hashira::Coupling::NamespacePlacement < Hashira::Coupling::Placement
  WEB = "(web)"

  TEST = "(test)"

  def self.build(project, catalog, _definitions) = new(project, catalog, Hashira::Coupling::Folders.new(project.paths))

  def initialize(project, catalog, folders, adapters = Hashira::Coupling::Adapters.new(catalog))
    super(project, catalog, folders)
    @adapters = adapters
  end

  def mode = :namespace

  def placed = catalog.flat_map { |definition| home(definition).map { [definition, it] } }

  def baseline = []

  def charge(file, nesting)
    return TEST if tested?(file)
    served?(file) ? WEB : owner(nesting)
  end

  def skip?(segments) = framework.rails? && @adapters.include?(segments.first)

  def aside?(package) = [WEB, TEST].include?(package)

  def test?(package) = package == TEST

  def folding(census) = Hashira::Coupling::Folding.new(domain, census, rails: framework.rails?)

  private

  def owner(nesting)
    nesting.reverse_each.filter_map { catalog.strip(it).first }.find { names.include?(it) } || folders.root
  end

  def home(definition)
    file = definition.site.to_s
    path = definition.to_a
    return [package(path.first)] unless apart?(file)
    return [] if claimed.include?(path)
    [tested?(file) ? TEST : WEB]
  end

  def package(name) = held.include?(name) ? folders.root : name

  def held = @_held ||= catalog.reject { it.site.nested? }.select { it.form.held? }.to_set { it.to_a.first }

  def domain = @_domain ||= catalog.reject { apart?(it.site.to_s) }

  def names = @_names ||= domain.to_set { it.to_a.first } - held

  def claimed = @_claimed ||= domain.to_set(&:to_a)

  def apart?(file) = served?(file) || tested?(file)

  def served?(file) = framework.rails? && Hashira::Coupling::Stratum.new(file).presentation?

  def tested?(file) = framework.rails? && listing.test?(file)
end
