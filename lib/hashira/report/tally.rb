# frozen_string_literal: true

class Hashira::Report::Tally
  SITE = /\A(?<path>[^\s:]+\.rb)(?::|\z)/

  def initialize(findings)
    @findings = findings
  end

  def to_h = rows.to_h { |kind, count, files| [kind, { count:, files: }] }

  def lines
    wide = rows.map { it.fetch(0).length }.max
    tall = rows.fetch(0).fetch(1).to_s.length
    rows.map { |kind, count, files| "  #{kind.ljust(wide)}  #{count.to_s.rjust(tall)} in #{reach(files)}" }
  end

  private

  def rows
    @_rows ||=
      kinds.map { |kind, group| [kind, group.size, files(group)] }.sort_by { |kind, count, _files| [-count, kind] }
  end

  def kinds = @findings.group_by { it.to_h.fetch(:kind) }

  def files(group) = group.flat_map { paths(it) }.uniq.size

  def paths(finding) = finding.quotes.filter_map { it[SITE, "path"] }

  def reach(files) = Hashira::Prose::Count.new(files, "file").to_s
end
