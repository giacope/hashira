# frozen_string_literal: true

require_relative "layout"
require_relative "placement"

class Hashira::Coupling::FolderPlacement < Hashira::Coupling::Placement
  class Layout < Hashira::Coupling::Layout
    def initialize(definitions, folders)
      super(folders)
      @definitions = definitions
    end

    def to_s = "folder"

    def to_a = @definitions.packages

    def aside?(_package) = false

    def test?(_package) = false

    def skip?(_segments) = false
  end

  def self.build(project, catalog, definitions)
    new(project, catalog, Hashira::Coupling::Folders.new(project.paths), definitions)
  end

  def initialize(project, catalog, folders, definitions)
    super(project, catalog, folders)
    @definitions = definitions
  end

  def placed = catalog.map { [it, folders.package(it.site.to_s)] }

  def charge(file, _nesting) = folders.package(file)

  def layout = Layout.new(@definitions, folders)

  def folding(_roster, _scope) = Hashira::Coupling::NoFolding.new
end
