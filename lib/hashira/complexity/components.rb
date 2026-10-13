# frozen_string_literal: true

class Hashira::Complexity::Components
  def initialize(graph)
    @graph = graph
    @index = {}
    @low = {}
    @stack = []
    @found = []
  end

  def to_a
    @graph.each_key { start(it) unless @index.key?(it) }
    @found
  end

  private

  def start(root)
    work = [[root, enter(root)]]
    step(work) until work.empty?
  end

  def enter(node)
    @low[node] = @index[node] = @index.size
    @stack.push(node)
    0
  end

  def step(work)
    frame = work.last
    child = @graph.fetch(frame.first)[frame.last]
    child ? advance(work, frame, child) : finish(work)
  end

  def advance(work, frame, child)
    frame[-1] += 1
    return work.push([child, enter(child)]) unless @index.key?(child)
    lower(frame.first, @index[child]) if @low.key?(child)
  end

  def finish(work)
    node, = work.pop
    low = @low[node]
    parent = work.last
    lower(parent.first, low) if parent
    close(node) if low == @index[node]
  end

  def lower(node, value) = @low[node] = [@low[node], value].min

  def close(node)
    component = []
    component << take until component.last == node
    @found << component
  end

  def take = @stack.pop.tap { @low.delete(it) }
end
