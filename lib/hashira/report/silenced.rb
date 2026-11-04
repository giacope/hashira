# frozen_string_literal: true

class Hashira::Report::Silenced
  STALE = "nothing it names fires there any more"

  def initialize(screened, io: $stdout)
    @screened = screened
    @io = io
  end

  def print
    _, suppressed, unused = @screened.to_a
    listing.waived("Suppressed", suppressed.map { |finding, directive| [finding, directive.said] })
    listing.print("Unused suppressions", unused) { "? #{it} — #{STALE}" }
  end

  private

  def listing = Hashira::Report::Listing.new(@io)
end
