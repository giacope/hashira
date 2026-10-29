# frozen_string_literal: true

require_relative "placement"

class Hashira::Coupling::FolderPlacement < Hashira::Coupling::Placement
  def self.build(project, catalog, definitions)
    new(project, catalog, Hashira::Coupling::Folders.new(project.paths), definitions)
  end

  def initialize(project, catalog, folders, definitions)
    super(project, catalog, folders)
    @definitions = definitions
  end

  def mode = :folder

  def placed = catalog.map { [it, folders.package(it.site.to_s)] }

  def baseline = @definitions.packages

  def charge(file, _nesting) = folders.package(file)

  def skip?(_segments) = false

  def aside?(_package) = false

  def test?(_package) = false

  def folding(_census) = Hashira::Coupling::NoFolding.new
end
