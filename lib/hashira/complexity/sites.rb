# frozen_string_literal: true

class Hashira::Complexity::Sites
  def initialize(tree)
    @tree = tree
  end

  def each(&)
    Hashira::Analysis::TypeWalk.new(@tree).walk do |type, full|
      owner = Hashira::Complexity::Owner.new(full)
      Hashira::Complexity::Body.new(type.body, owner, type).each(&)
    end
  end
end
