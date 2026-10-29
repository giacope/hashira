# frozen_string_literal: true

class Hashira::Report::FindingsText
  def initialize(findings, screened, unjudged, page)
    @findings = findings
    @screened = screened
    @unjudged = unjudged
    @page = page
  end

  def print
    all = @findings.to_a
    @page.puts("Findings (#{all.size}):")
    list(all)
    @page.waived("Accepted", @findings.to_h)
    @page.silenced(@screened)
    @page.puts("\n  Full evidence + machine format: hashira --json") unless all.empty?
  end

  private

  def list(all)
    return @page.puts("  #{@unjudged.verdict}") if all.empty?
    @page.table(Hashira::Report::FindingList, all)
  end
end
