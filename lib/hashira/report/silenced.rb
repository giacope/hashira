# frozen_string_literal: true

class Hashira::Report::Silenced
  def initialize(screened, io: $stdout)
    @screened = screened
    @io = io
  end

  def print
    suppressed
    unused
  end

  private

  def suppressed
    silenced = @screened.suppressed
    @io.puts("\nSuppressed (#{silenced.size}):") unless silenced.empty?
    silenced.each { |finding, directive| @io.puts("  ~ #{finding.kind}/#{finding.package} — #{said(directive)}") }
  end

  def said(directive) = "#{directive.reason} (#{directive.site})"

  def unused
    stale = @screened.unused
    return if stale.empty?
    @io.puts("\nUnused suppressions (#{stale.size}) — nothing they name fires there any more:")
    stale.each { @io.puts("  ? #{it.kinds.join(",")} at #{it.site}") }
  end
end
