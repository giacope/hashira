# frozen_string_literal: true

class Hashira::Duplication::Harvest
  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def fragments = @_fragments ||= @trees.flat_map { |path, tree| candidates(path, tree).fragments }

  private

  def candidates(path, tree) = Hashira::Duplication::Candidates.new(@project.relative(path), tree)
end
