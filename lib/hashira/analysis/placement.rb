# frozen_string_literal: true

class Hashira::Analysis::Placement
  def self.build(packaging, project, catalog)
    {
      folder: Hashira::Analysis::FolderPlacement,
      namespace: Hashira::Analysis::NamespacePlacement
    }.fetch(packaging).new(project, catalog)
  end

  def initialize(project, catalog)
    @project = project
    @catalog = catalog
  end

  private

  attr_reader :project, :catalog
end
