module Tree
  class Taxon
    attr_reader :name, :content_id
    attr_accessor :parent_node

    def initialize(name, content_id)
      @name = name
      @content_id = content_id
    end
  end
end
