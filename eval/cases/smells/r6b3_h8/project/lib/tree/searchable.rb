module Tree
  module Searchable
    extend ActiveSupport::Concern

    module ClassMethods
      def search(nodes)
        nodes.map { |node| node.title.to_s + node.title.to_s + node.title.to_s }
      end
    end
  end
end
