# frozen_string_literal: true

class Hashira::Complexity::Sites
  def initialize(tree)
    @tree = tree
  end

  def each(&)
    Hashira::Analysis::TypeWalk.each(@tree) do |type, full|
      Hashira::Complexity::Body.new(type.body, Hashira::Complexity::Owner.new(segments: full)).each(&)
    end
  end
end
