# frozen_string_literal: true

class Hashira::Focus
  SITE = /\A(?<path>[^\s:]+\.rb):/

  def initialize(paths, only)
    @paths = paths
    @only = only
  end

  def narrowing? = !@only.empty?

  def narrow(findings)
    return findings unless narrowing?
    findings.select { named?(it) }
  end

  private

  def wanted = @_wanted ||= @only.select { covered?(it) }.map { @paths.relative(it) }

  def covered?(path) = @paths.to_a.any? { path.start_with?("#{it}/") }

  def named?(finding) = sites(finding).any? { wanted.include?(it) }

  def sites(finding) = finding.quotes.filter_map { SITE.match(it)&.[](:path) }
end
