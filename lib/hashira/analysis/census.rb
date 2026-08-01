# frozen_string_literal: true

class Hashira::Analysis::Census
  def initialize(project, trees, packaging: :folder)
    @catalog = Hashira::Analysis::Catalog.new(Hashira::Analysis::Definitions.new(project, trees))
    @placement = Hashira::Analysis::Placement.build(packaging, project, @catalog)
    @folding = Hashira::Analysis::NoFolding
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

  def resolve(segments, nesting = []) = resolver.resolve(segments, nesting)

  def pinpoint(segments) = resolver.pinpoint(segments)

  def charge(file, nesting) = translate(@placement.charge(file, nesting))

  private

  def tally
    Hashira::Analysis::Roster.new(@placement.placed.map { |definition, package| [definition, translate(package)] })
  end

  def settle
    @folding = @placement.folding(self)
    @roster = tally unless @folding.map.empty?
  end

  def translate(package) = @folding.map.fetch(package, package)

  def resolver = Hashira::Analysis::Resolver.new(@roster.registry, @catalog, @placement)
end
