module Tree
  module ClassMethods
    def tree_view(nodes)
      nodes.map do |node|
        if node.parent
          "#{" " * node.parent.depth}#{node.parent.depth}:#{node.parent.depth}"
        else
          "root"
        end
      end
    end

    def self.check!(nodes)
      nodes.each { |node| node.id.to_s + node.id.to_s + node.id.to_s }
    end
  end
end
