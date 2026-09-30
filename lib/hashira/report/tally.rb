# frozen_string_literal: true

class Hashira::Report::Tally
  SITE = /\A(?<path>[^\s:]+\.rb)(?::|\z)/

  Row =
    Data.define(:kind, :count, :files) do
      def line(wide, tall) = "  #{kind.ljust(wide)}  #{count.to_s.rjust(tall)} in #{reach}"

      def reach = Hashira::Report::Phrases.count(files, "file")
    end

  def initialize(findings)
    @findings = findings
  end

  def rows = @findings.group_by(&:kind).map { |kind, group| row(kind, group) }.sort_by { [-it.count, it.kind] }

  def to_h = rows.to_h { [it.kind, { count: it.count, files: it.files }] }

  private

  def row(kind, group) = Row.new(kind:, count: group.size, files: group.flat_map { paths(it) }.uniq.size)

  def paths(finding) = [finding.package, finding.site, *finding.evidence].filter_map { it[SITE, "path"] }
end
