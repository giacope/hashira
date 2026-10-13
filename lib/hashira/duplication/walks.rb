# frozen_string_literal: true

class Hashira::Duplication::Walks
  def nodes(roots) = roots.flat_map { walked[it] ||= Hashira::Analysis::NodeWalk.collect(it) }

  def muted(roots) = roots.flat_map { quiet[it] ||= Hashira::Duplication::Quiet.new(nodes([it]), self).nodes }

  private

  def walked = @_walked ||= {}.compare_by_identity

  def quiet = @_quiet ||= {}.compare_by_identity
end
