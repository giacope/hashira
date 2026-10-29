# frozen_string_literal: true

class Hashira::Coupling::Placement
  def self.build(packaging, project, catalog)
    {
      folder: Hashira::Coupling::FolderPlacement,
      namespace: Hashira::Coupling::NamespacePlacement
    }.fetch(packaging).new(project, catalog)
  end

  def initialize(project, catalog, folders = Hashira::Coupling::Folders.new(project.paths))
    @project = project
    @catalog = catalog
    @folders = folders
  end

  private

  attr_reader :project, :catalog, :folders

  def paths = @_paths ||= project.paths

  def framework = @_framework ||= project.framework

  def listing = @_listing ||= project.listing
end
