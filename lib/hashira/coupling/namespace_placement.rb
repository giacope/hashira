# frozen_string_literal: true

require_relative "placement"

class Hashira::Coupling::NamespacePlacement < Hashira::Coupling::Placement
  WEB = "(web)"

  TEST = "(test)"

  def mode = :namespace

  def placed = catalog.flat_map { |definition| home(definition).map { [definition, it] } }

  def baseline = []

  def charge(file, nesting)
    return TEST if tested?(file)
    served?(file) ? WEB : owner(nesting)
  end

  def skip?(segments) = framework.rails? && adapters.include?(segments.first)

  def aside?(package) = [WEB, TEST].include?(package)

  def test?(package) = package == TEST

  def folding(census) = Hashira::Coupling::Folding.new(domain, census, rails: framework.rails?)

  private

  def adapters = @_adapters ||= Hashira::Coupling::Adapters.new(catalog)

  def owner(nesting)
    nesting.reverse_each.filter_map { catalog.strip(it).first }.find { names.include?(it) } || folders.root
  end

  def home(definition)
    file = definition.file
    return [package(definition.name)] unless apart?(file)
    return [] if claimed.include?(definition.path)
    [tested?(file) ? TEST : WEB]
  end

  def package(name) = held.include?(name) ? folders.root : name

  def held = @_held ||= catalog.reject(&:nested?).select { it.value? || it.engine? }.to_set(&:name)

  def domain = @_domain ||= catalog.reject { apart?(it.file) }

  def names = @_names ||= domain.to_set(&:name) - held

  def claimed = @_claimed ||= domain.to_set(&:path)

  def apart?(file) = served?(file) || tested?(file)

  def served?(file) = framework.rails? && Hashira::Coupling::Stratum.new(file).presentation?

  def tested?(file) = framework.rails? && listing.test?(file)
end
