# frozen_string_literal: true

class Hashira::Coupling::Census
  def initialize(placement, catalog, reading, none = Hashira::Coupling::NoFolding.new)
    @placement = placement
    @catalog = catalog
    @reading = reading
    @none = none
  end

  def graph
    loose = Hashira::Coupling::Roster.new(@placement, @none)
    bare = Hashira::Coupling::Scope.new(loose, @catalog, layout)
    unfolded = Hashira::Coupling::Lazy.new { graphed(loose, bare, @none, unfolded) }
    folding = @placement.folding(loose, bare)
    roster = Hashira::Coupling::Roster.new(@placement, folding)
    graphed(roster, Hashira::Coupling::Scope.new(roster, @catalog, layout), folding, unfolded)
  end

  private

  def layout = @placement.layout

  def graphed(roster, scope, folding, unfolded)
    ledger = Hashira::Coupling::Ledger.new(@placement, folding, @catalog, roster)
    tally = Hashira::Coupling::Tally.new(roster, layout, folding)
    map = Hashira::Coupling::EdgeMap.new(scope, ledger, @catalog, @reading)
    sightings = Hashira::Coupling::Sightings.new(@reading, scope, ledger, @catalog)
    Hashira::Coupling::Graph.new(map, tally, sightings, unfolded)
  end
end
