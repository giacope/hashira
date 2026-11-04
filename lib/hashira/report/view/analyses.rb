# frozen_string_literal: true

class Hashira::Report::View::Analyses
  def initialize(graph, complexity, duplication, hotspots)
    @graph = graph
    @complexity = complexity
    @duplication = duplication
    @hotspots = hotspots
  end

  def texts(paths, listing, page)
    [
      *@graph.map { Hashira::Report::CouplingText.new(it, paths, listing, page) },
      *@complexity.map { Hashira::Report::Tabled.new(Hashira::Report::ComplexityTable, it, page) },
      *@hotspots.map { Hashira::Report::Tabled.new(Hashira::Report::HotspotTable, it, page) }
    ]
  end

  def about(paths, listing) = Hashira::Report::Json::About.new(@graph, paths, listing)

  def pieces
    [
      *@graph.map { Hashira::Report::Json::Coupling.new(it) },
      *@complexity.map { Hashira::Report::Json::Complexity.new(it) },
      *@duplication.map { Hashira::Report::Json::Duplication.new(it) },
      *@hotspots.map { Hashira::Report::Json::Hotspots.new(it) }
    ]
  end
end
