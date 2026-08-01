# frozen_string_literal: true

require_relative "placement"

class Hashira::Analysis::FolderPlacement < Hashira::Analysis::Placement
  def mode = :folder

  def placed = catalog.map { [it, it.folder] }

  def baseline = catalog.folders

  def charge(file, _nesting) = project.package(file)

  def skip?(_segments) = false

  def folding(_census) = Hashira::Analysis::NoFolding
end
