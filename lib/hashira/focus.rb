# frozen_string_literal: true

class Hashira::Focus
  def initialize(project, paths)
    @project = project
    @paths = paths
  end

  def narrowing? = !@paths.empty?

  def narrow(findings)
    return findings unless narrowing?
    findings.select { it.names?(wanted) }
  end

  private

  def wanted = @_wanted ||= @paths.select { covered?(it) }.map { @project.relative(it) }

  def covered?(path) = @project.directories.any? { path.start_with?("#{it}/") }
end
