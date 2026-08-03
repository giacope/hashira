# frozen_string_literal: true

class Hashira::Coupling::Placement
  def self.build(packaging, project, catalog)
    {
      folder: Hashira::Coupling::FolderPlacement,
      namespace: Hashira::Coupling::NamespacePlacement
    }.fetch(packaging).new(project, catalog)
  end

  def initialize(project, catalog)
    @project = project
    @catalog = catalog
  end

  private

  attr_reader :project, :catalog
end
