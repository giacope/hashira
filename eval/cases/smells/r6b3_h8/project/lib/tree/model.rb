module Tree
  module Model
    def self.included(base)
      base.extend Tree::ClassMethods
    end

    def verify = Tree::ClassMethods.check!([self])
  end
end
