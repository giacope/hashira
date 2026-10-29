# frozen_string_literal: true

class Hashira::Report::View::Analyses
  def initialize(graph, complexity, duplication, hotspots)
    @graph = graph
    @complexity = complexity
    @duplication = duplication
    @hotspots = hotspots
  end

  def texts(project, page)
    [
      *[@graph].compact.map { Hashira::Report::CouplingText.new(it, project, page) },
      *[@complexity].compact.map { Hashira::Report::Tabled.new(Hashira::Report::ComplexityTable, it, page) },
      *[@hotspots].compact.map { Hashira::Report::Tabled.new(Hashira::Report::HotspotTable, it, page) }
    ]
  end

  def about(project) = Hashira::Report::Json::About.new(@graph, project)

  def pieces
    [
      *[@graph].compact.map { Hashira::Report::Json::Coupling.new(it) },
      *[@complexity].compact.map { Hashira::Report::Json::Complexity.new(it) },
      *[@duplication].compact.map { Hashira::Report::Json::Duplication.new(it) },
      *[@hotspots].compact.map { Hashira::Report::Json::Hotspots.new(it) }
    ]
  end
end
