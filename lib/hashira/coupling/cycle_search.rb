# frozen_string_literal: true

class Hashira::Coupling::CycleSearch
  def initialize(dependencies, package)
    @dependencies = dependencies
    @package = package
  end

  def path
    links = predecessors
    unwind([@package], links) if links.key?(@package)
  end

  private

  def predecessors
    found = {}
    queue = @dependencies[@package].to_a.each { found[it] = @package }
    until queue.empty? || found.key?(@package)
      node = queue.shift
      fresh = @dependencies[node].reject { found.key?(it) }.uniq
      fresh.each { found[it] = node }
      queue.concat(fresh)
    end
    found
  end

  def unwind(path, links)
    first = path.first
    return path if first == @package && path.size > 1
    unwind([links.fetch(first), *path], links)
  end
end
