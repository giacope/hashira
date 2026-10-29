# frozen_string_literal: true

class Hashira::Coupling::Graph
  def self.build(project, trees)
    framework = project.framework
    definitions = Hashira::Coupling::Definitions.build(project, trees)
    catalog = Hashira::Coupling::Catalog.build(project, trees, definitions)
    placement = Hashira::Coupling::Placement.build(framework.packaging, project, catalog, definitions)
    reading = Hashira::Coupling::Reading.build(project, trees, definitions)
    Hashira::Coupling::Census.new(placement, catalog, reading).graph
  end

  def initialize(map, tally, sightings, unfolded)
    @map = map
    @tally = tally
    @sightings = sightings
    @unfolded = unfolded
  end

  def packages = Hashira::Coupling::Packages.new(Hashira::Coupling::Network.new(@map, @tally), @map, @unfolded)

  def edges = Hashira::Coupling::Edges.new(@map, Hashira::Coupling::Network.new(@map, @tally), @tally)

  def code = @sightings.code

  def lookup = @sightings.lookup
end
