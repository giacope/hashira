# frozen_string_literal: true

class Hashira::Report::View::Verdicts
  def initialize(findings, screened, unjudged)
    @findings = findings
    @screened = screened
    @unjudged = unjudged
  end

  def text(page) = Hashira::Report::FindingsText.new(@findings, @screened, @unjudged, page)

  def listed = Hashira::Report::Json::Verdict.new(@findings, @screened)

  def unjudged = Hashira::Report::Json::Unjudged.new(@unjudged)
end
