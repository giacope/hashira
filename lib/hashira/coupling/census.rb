# frozen_string_literal: true

class Hashira::Coupling::Census
  def initialize(project, trees, packaging: :folder, folded: true)
    @project = project
    @trees = trees
    @packaging = packaging
    @folded = folded
  end

  def unfolded = self.class.new(@project, @trees, packaging: @packaging, folded: false)

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

  def locate(segments, nesting) = scope.locate(segments, nesting)

  def owner(path) = scope.owner(path)

  def files(path) = (@_files ||= catalog.group_by(&:path).transform_values { it.map(&:file).uniq }).fetch(path, [])

  def charge(file, nesting) = translate(placement.charge(file, nesting))

  def aside?(package) = placement.aside?(package)

  def test?(package) = placement.test?(package)

  def home(file) = homes[file] || charge(file, [])

  def classes = @_classes ||= catalog.select(&:klass?).to_set { it.path.join("::") }

  def owned?(path) = territory.owned?(path)

  def inflection
    @_inflection ||= Hashira::Coupling::Inflection.new(Hashira::Coupling::Inflections.of(@project.inflections))
  end

  def associations = @_associations ||= Hashira::Coupling::Associations.new(inflection)

  private

  def territory = catalog.territory

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
    refold if @folded
  end

  def refold
    @_folding = placement.folding(self)
    @_roster = tally
  end

  def type?(segments) = roster.type?(segments)

  def homes = @_homes ||= placement.placed.select(&:last).group_by { it.first.file }.transform_values { dominant(it) }

  def dominant(placed) = placed.map { translate(it.last) }.tally.max_by(&:last).first

  def tally
    Hashira::Coupling::Roster.new(placement.placed.map { |definition, package| [definition, translate(package)] })
  end

  def translate(package) = folding.map.fetch(package, package)

  def scope
    current = roster
    (@_scopes ||= {})[current] ||= Hashira::Coupling::Scope.new(current.registry, catalog, placement)
  end
end
