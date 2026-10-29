# frozen_string_literal: true

class Hashira::Project
  def initialize(requested, home: ".", packaging: :auto, boundaries: [])
    @requested = requested
    @home = home
    @packaging = packaging
    @boundaries = boundaries
  end

  def paths = Hashira::Paths.new(directories, @home)

  def listing = Hashira::Listing.new(*scan, paths)

  def framework = Hashira::Framework.new(directories, engines, @packaging)

  def boundaries(trees) = Hashira::Boundaries.new(@boundaries, trees, paths)

  private

  def directories = @_directories ||= Hashira::Directories.new(@requested).resolved

  def scan = @_scan ||= Hashira::Sources.new(directories, entries:).then { [it.files, it.skipped] }

  def entries = Hashira::Directories.new(@requested).entries(directories)

  def engines = @_engines ||= Hashira::Engine.new(directories, @home).namespaces
end
