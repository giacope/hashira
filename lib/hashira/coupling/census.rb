# frozen_string_literal: true

class Hashira::Coupling::Census
  def initialize(project, trees, packaging: :folder)
    @catalog = Hashira::Coupling::Catalog.new(Hashira::Coupling::Definitions.new(project, trees))
    @placement = Hashira::Coupling::Placement.build(packaging, project, @catalog)
    @folding = Hashira::Coupling::NoFolding
    @roster = tally
    settle
  end

  def packaging = @placement.mode

  def types = @roster.types

  def prefix = @catalog.prefix

  def origins = @roster.origins

  def roots = @catalog.roots

  def packages = @roster.packages | @placement.baseline

  def folds = @folding.disclosed

  def strip(segments) = @catalog.strip(segments)

  def holder(segments)
    path = strip(segments)
    (path.length.downto(1).map { path.first(it) }.find { type?(it) } || path).join("::")
  end

  def resolve(segments, nesting = []) = scope.resolve(segments, nesting)

  def pinpoint(segments) = scope.pinpoint(segments)

  def charge(file, nesting) = translate(@placement.charge(file, nesting))

  private

  def type?(segments) = @roster.origins.key?(segments.join("::"))

  def tally
    Hashira::Coupling::Roster.new(@placement.placed.map { |definition, package| [definition, translate(package)] })
  end

  def settle
    @folding = @placement.folding(self)
    @roster = tally unless @folding.map.empty?
  end

  def translate(package) = @folding.map.fetch(package, package)

  def scope = Hashira::Coupling::Scope.new(@roster.registry, @catalog, @placement)
end
