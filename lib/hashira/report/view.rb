# frozen_string_literal: true

class Hashira::Report::View
  def initialize(project, analyses, verdicts, layout = Hashira::Report::View::Layout.new)
    @project = project
    @analyses = analyses
    @verdicts = verdicts
    @layout = layout
  end

  def text(io = $stdout)
    page = @layout.page(io)
    Hashira::Report::Text.new([*@analyses.texts(@project, page), @verdicts.text(page)])
  end

  def json(io = $stdout)
    listed = [@verdicts.listed, *@analyses.pieces]
    pieces = [@analyses.about(@project), *listed, Hashira::Report::Json::Withheld.new(listed), @verdicts.unjudged]
    @layout.json(pieces, io)
  end
end
