# frozen_string_literal: true

class Hashira::Coupling::Census
  def initialize(project, trees, packaging: :folder, folded: true)
    @project = project
    @trees = trees
    @packaging = packaging
    @folded = folded
  end

  def unfolded = @_unfolded ||= self.class.new(@project, @trees, packaging: @packaging, folded: false)

  def packaging = placement.mode

  def types = roster.to_h

  def prefix = Hashira::Coupling::Naming.new(definitions, framework).to_a

  def origins = roster.origins

  def roots = definitions.roots

  def packages = roster.to_a | placement.baseline

  def folds = folding.disclosed

  def strip(segments) = catalog.strip(segments)

  def holder(segments)
    path = strip(segments)
    (path.length.downto(1).map { path.first(it) }.find { type?(it) } || path).join("::")
  end

  def resolve(segments, nesting = []) = scope.resolve(segments, nesting)

  def pinpoint(segments) = scope.pinpoint(segments)

  def locate(segments, nesting) = scope.locate(segments, nesting)

  def vias(path) = scope.vias(path)

  def files(path) = (@_files ||= catalog.group_by(&:to_a).transform_values { |found| filed(found) }).fetch(path, [])

  def charge(file, nesting, target)
    return placed(file, nesting) unless nesting.empty?
    (homes[file] if own?(file, target)) || tops[file] || placed(file, nesting)
  end

  def aside?(package) = placement.aside?(package)

  def test?(package) = placement.test?(package)

  def home(file) = homes[file] || placed(file, [])

  def classes = @_classes ||= catalog.select { it.form.klass? }.to_set { it.to_a.join("::") }

  def owned?(path) = catalog.owned?(path)

  def unlayered(layers, files) = files.reject { layers.rank(it, home(it)) }

  def plural(word) = inflection.plural(word)

  def inflection = @_inflection ||= framework.inflection

  def associations = @_associations ||= Hashira::Coupling::Associations.new(inflection)

  private

  def framework = @_framework ||= @project.framework

  def definitions = @_definitions ||= Hashira::Coupling::Definitions.build(@project, @trees)

  def catalog = @_catalog ||= Hashira::Coupling::Catalog.build(@project, @trees, definitions)

  def placement = @_placement ||= Hashira::Coupling::Placement.build(@packaging, @project, catalog, definitions)

  def roster = @_roster ||= tally

  def folding = @_folding ||= @folded ? placement.folding(unfolded) : Hashira::Coupling::NoFolding.new

  def type?(segments) = roster.type?(segments)

  def placed(file, nesting) = translate(placement.charge(file, nesting))

  def own?(file, target) = !Array(target).empty? && files(target).include?(file)

  def homes = @_homes ||= dominants(placement.placed)

  def tops = @_tops ||= dominants(placement.placed.select { it.first.site.top? })

  def dominants(placed) = placed.select(&:last).group_by { it.first.site.to_s }.transform_values { dominant(it) }

  def filed(definitions) = definitions.map { it.site.to_s }.uniq

  def dominant(placed) = placed.map { translate(it.last) }.tally.max_by(&:last).fetch(0)

  def tally
    Hashira::Coupling::Roster.new(placement.placed.map { |definition, package| [definition, translate(package)] })
  end

  def translate(package) = folding.map.fetch(package, package)

  def scope
    current = roster
    (@_scopes ||= {})[current] ||= Hashira::Coupling::Scope.new(current, catalog, placement)
  end
end
