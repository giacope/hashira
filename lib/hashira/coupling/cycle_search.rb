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
    @_predecessor = {}
    @_queue = @dependencies[@package].to_a.each { @_predecessor[it] = @package }
  end

  def cycle?
    prepare
    while (node = @_queue.shift)
      return true if node == @package
      visit(node)
    end
  end

  def visit(node)
    @dependencies[node].each do |neighbor|
      next if @_predecessor.key?(neighbor)
      @_predecessor[neighbor] = node
      @_queue << neighbor
    end
  end

  def unwind(path)
    first = path.first
    return path if first == @package && path.size > 1
    unwind(path.unshift(@_predecessor[first]))
  end
end
