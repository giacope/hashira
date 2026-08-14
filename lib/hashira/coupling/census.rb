# frozen_string_literal: true

class Hashira::Coupling::Census
  def initialize(project, trees, packaging: :folder)
    @project = project
    @trees = trees
    @packaging = packaging
  end

  def packaging = placement.mode

  def types = roster.types

  def prefix = catalog.prefix

  def origins = roster.origins

  def roots = catalog.roots

  def packages = roster.packages | placement.baseline

  def folds = folding.disclosed

  def strip(segments) = catalog.strip(segments)

  def holder(segments)
    path = strip(segments)
    (path.length.downto(1).map { path.first(it) }.find { type?(it) } || path).join("::")
  end

  def resolve(segments, nesting = []) = scope.resolve(segments, nesting)

  def pinpoint(segments) = scope.pinpoint(segments)

  def charge(file, nesting) = translate(placement.charge(file, nesting))

  private

  def catalog = @_catalog ||= Hashira::Coupling::Catalog.new(Hashira::Coupling::Definitions.new(@project, @trees))

  def placement = @_placement ||= Hashira::Coupling::Placement.build(@packaging, @project, catalog)

  def roster
    settled
    @_roster
  end

  def folding
    settled
    @_folding
  end

  def settled
    return if @_settled
    @_settled = true
    @_folding = Hashira::Coupling::NoFolding
    @_roster = tally
    refold
  end

  def refold
    @_folding = placement.folding(self)
    @_roster = tally unless @_folding.map.empty?
  end

  def type?(segments) = roster.type?(segments)

  def tally
    Hashira::Coupling::Roster.new(placement.placed.map { |definition, package| [definition, translate(package)] })
  end

  def translate(package) = folding.map.fetch(package, package)

  def scope = Hashira::Coupling::Scope.new(roster.registry, catalog, placement)
end
