module Shop
  class RelationIndexer
    def initialize(index)
      @index = index
    end

    def reindex(relation)
      relation = relation.except(:includes, :preload)
      relation = relation.except(:select).select(relation.primary_key) unless relation.klass.method_defined?(:routing)
      @index.import(relation)
      @index.refresh
    end
  end
end
