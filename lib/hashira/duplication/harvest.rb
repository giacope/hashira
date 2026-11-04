# frozen_string_literal: true

class Hashira::Duplication::Harvest
  def initialize(paths, trees)
    @paths = paths
    @trees = trees
  end

  def fragments = @_fragments ||= @trees.flat_map { |path, tree| candidates(path, tree).fragments }

  private

  def candidates(path, tree) = Hashira::Duplication::Candidates.new(@paths.relative(path), tree)
end
