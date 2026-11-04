# frozen_string_literal: true

class Hashira::Coupling::Ledger
  def initialize(placement, folding, catalog, roster)
    @placement = placement
    @folding = folding
    @catalog = catalog
    @roster = roster
  end

  def charge(file, nesting, target)
    return placed(file, nesting) unless nesting.empty?
    (homes[file] if own?(file, target)) || tops[file] || placed(file, nesting)
  end

  def home(file) = homes[file] || placed(file, [])

  def files(path) = (@_files ||= @catalog.group_by(&:to_a).transform_values { |found| filed(found) }).fetch(path, [])

  def holder(segments)
    path = @catalog.strip(segments)
    (path.length.downto(1).map { path.first(it) }.find { @roster.type?(it) } || path).join("::")
  end

  private

  def filed(definitions) = definitions.map { it.site.to_s }.uniq

  def placed(file, nesting) = translate(@placement.charge(file, nesting))

  def own?(file, target) = !Array(target).empty? && files(target).include?(file)

  def homes = @_homes ||= dominants(@placement.placed)

  def tops = @_tops ||= dominants(@placement.placed.select { it.first.site.top? })

  def dominants(placed) = placed.select(&:last).group_by { it.first.site.to_s }.transform_values { dominant(it) }

  def dominant(placed) = placed.map { translate(it.last) }.tally.max_by(&:last).fetch(0)

  def translate(package) = @folding.map.fetch(package, package)
end
