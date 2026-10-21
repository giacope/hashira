# frozen_string_literal: true

require_relative "placement"

class Hashira::Coupling::NamespacePlacement < Hashira::Coupling::Placement
  WEB = "(web)"

  TEST = "(test)"

  def mode = :namespace

  def placed = catalog.map { [it, home(it)] }

  def baseline = []

  def charge(file, nesting)
    return TEST if tested?(file)
    served?(file) ? WEB : owner(nesting)
  end

  def skip?(segments) = project.rails? && adapters.include?(segments.first)

  def aside?(package) = [WEB, TEST].include?(package)

  def test?(package) = package == TEST

  def folding(census) = Hashira::Coupling::Folding.new(domain, census, suffixes: suffixes)

  private

  def adapters = @_adapters ||= Hashira::Coupling::Adapters.new(catalog)

  def owner(nesting)
    nesting.reverse_each.filter_map { catalog.strip(it).first }.find { names.include?(it) } || project.root
  end

  def home(definition)
    file = definition.file
    return package(definition.name) unless apart?(file)
    (tested?(file) ? TEST : WEB) unless claimed.include?(definition.path)
  end

  def package(name) = held.include?(name) ? project.root : name

  def held = @_held ||= catalog.reject(&:nested?).select { it.value? || it.engine? }.to_set(&:name)

  def domain = @_domain ||= catalog.reject { apart?(it.file) }

  def names = @_names ||= domain.to_set(&:name) - held

  def claimed = @_claimed ||= domain.to_set(&:path)

  def apart?(file) = served?(file) || tested?(file)

  def served?(file) = project.rails? && Hashira::Coupling::Stratum.presentation?(file)

  def tested?(file) = project.rails? && project.test?(file)

  def suffixes = project.rails? ? Hashira::Coupling::Folding::SUFFIXES : []
end
