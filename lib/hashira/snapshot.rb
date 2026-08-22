# frozen_string_literal: true

class Hashira::Snapshot
  def initialize(project)
    @project = project
  end

  def paths = @_paths ||= @project.files

  def sources = @_sources ||= paths.to_h { [it, read(it)] }

  def size = paths.size

  private

  def read(path)
    File.read(path).freeze
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
