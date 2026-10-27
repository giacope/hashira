module Treed
  def self.included(base)
    base.acts_as_tree
    base.has_paper_trail
  end
end
