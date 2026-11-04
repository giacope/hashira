# frozen_string_literal: true

class Hashira::Coupling::Lookup
  def initialize(scope, catalog)
    @scope = scope
    @catalog = catalog
  end

  def locate(segments, nesting) = @scope.locate(segments, nesting)

  def vias(path) = @scope.vias(path)

  def strip(path) = @catalog.strip(path)

  def owned?(path) = @catalog.owned?(path)
end
