module Shop
  class Relation
    attr_reader :model
    alias_method :klass, :model

    def initialize(model)
      @model = model
    end

    def only(*keys) = Relation.new(@model.only(*keys))

    def except(*keys) = Relation.new(@model.except(*keys))
  end
end
