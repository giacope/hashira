# frozen_string_literal: true

class Hashira::Coupling::Catalog
  include Enumerable

  def self.build(project, trees, definitions)
    paths = project.paths
    naming = Hashira::Coupling::Naming.new(definitions, project.framework)
    entries = Hashira::Coupling::Entries.new(definitions, naming)
    opened = Hashira::Coupling::Opened.new(entries, definitions, naming)
    dependencies = Hashira::Coupling::Dependencies.new(paths.expand("."))
    claims = Hashira::Coupling::Claims.new(opened, dependencies, Hashira::Coupling::Spellings.new(trees))
    new(entries, naming, Hashira::Coupling::Territory.new(entries, claims))
  end

  def initialize(entries, naming, territory)
    @entries = entries
    @naming = naming
    @territory = territory
  end

  def each(&) = @entries.each(&)

  def strip(path) = @naming.strip(path)

  def rooted(path) = @naming.rooted(path)

  def owned?(path) = @territory.owned?(path)

  def claimed?(full) = strip(full).then { it.empty? || owned?(it) }
end
