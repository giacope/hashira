# frozen_string_literal: true

class Hashira::Coupling::CycleSearch
  def initialize(dependencies, package)
    @dependencies = dependencies
    @package = package
  end

  def path
    unwind([@package]) if cycle?
  end

  private

  def prepare
    @predecessor = {}
    @queue = @dependencies[@package].to_a.each { @predecessor[it] = @package }
  end

  def cycle?
    prepare
    while (node = @queue.shift)
      return true if node == @package
      visit(node)
    end
  end

  def visit(node)
    @dependencies[node].each do |neighbor|
      next if @predecessor.key?(neighbor)
      @predecessor[neighbor] = node
      @queue << neighbor
    end
  end

  def unwind(path)
    first = path.first
    return path if first == @package && path.size > 1
    unwind(path.unshift(@predecessor[first]))
  end
end
