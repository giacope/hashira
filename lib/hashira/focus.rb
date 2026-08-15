# frozen_string_literal: true

class Hashira::Focus
  SITE = /\A(?<path>[^\s:]+\.rb):/

  def initialize(project, paths)
    @project = project
    @paths = paths
  end

  def narrowing? = !@paths.empty?

  def narrow(findings)
    return findings unless narrowing?
    findings.select { named?(it) }
  end

  private

  def wanted = @_wanted ||= @paths.select { covered?(it) }.map { @project.relative(it) }

  def covered?(path) = @project.directories.any? { path.start_with?("#{it}/") }

  def named?(finding) = sites(finding).any? { wanted.include?(it) }

  def sites(finding) = quotes(finding).filter_map { SITE.match(it)&.[](:path) }

  def quotes(finding) = [finding.package, finding.detail.to_h[:site], *finding.evidence].compact
end
