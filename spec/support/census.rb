# frozen_string_literal: true

module Fixtures
  class Census
    def initialize(project, trees)
      framework = project.framework
      definitions = Hashira::Coupling::Definitions.build(project, trees)
      catalog = Hashira::Coupling::Catalog.build(project, trees, definitions)
      placement = Hashira::Coupling::Placement.build(framework.packaging, project, catalog, definitions)
      folding = folded(placement, catalog)
      @roster = Hashira::Coupling::Roster.new(placement, folding)
      @tally = Hashira::Coupling::Tally.new(@roster, placement.layout, folding)
      @scope = Hashira::Coupling::Scope.new(@roster, catalog, placement.layout)
      @ledger = Hashira::Coupling::Ledger.new(placement, folding, catalog, @roster)
      @naming = Hashira::Coupling::Naming.new(definitions, framework)
    end

    def packages = @tally.to_a

    def types = @tally.to_h

    def folds = @tally.folds

    def resolve(segments, nesting = []) = @scope.resolve(segments, nesting)

    def origins = @roster.origins

    def prefix = @naming.to_a

    def holder(segments) = @ledger.holder(segments)

    private

    def folded(placement, catalog)
      loose = Hashira::Coupling::Roster.new(placement, Hashira::Coupling::NoFolding.new)
      placement.folding(loose, Hashira::Coupling::Scope.new(loose, catalog, placement.layout))
    end
  end
end
