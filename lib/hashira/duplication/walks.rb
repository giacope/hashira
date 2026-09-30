# frozen_string_literal: true

class Hashira::Duplication::Walks
  def nodes(roots) = roots.flat_map { walked[it] ||= Hashira::Analysis::NodeWalk.collect(it) }

  private

  def walked = @_walked ||= {}.compare_by_identity
end
