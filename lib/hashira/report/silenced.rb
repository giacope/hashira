# frozen_string_literal: true

class Hashira::Report::Silenced
  STALE = "nothing it names fires there any more"

  def initialize(screened, io: $stdout)
    @screened = screened
    @io = io
  end

  def print
    listing.waived("Suppressed", @screened.suppressed.map { |finding, directive| [finding, said(directive)] })
    listing.print("Unused suppressions", @screened.unused) { "? #{it.kinds.join(",")} at #{it.site} — #{STALE}" }
  end

  private

  def listing = Hashira::Report::Listing.new(@io)

  def said(directive) = "#{directive.reason} (#{directive.site})"
end
