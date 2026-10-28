# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Gift
  def initialize(call, nesting, host = call.receiver)
    @call = call
    @nesting = nesting
    @host = host
  end

  def to_a
    host = root(@host)
    Array(@call.arguments&.arguments).filter_map { offered(it) }.map { [*lexical(host), *it] }
  end

  private

  def offered(given)
    return ([@nesting.last, []] if @nesting.any?) if given.is_a?(Prism::SelfNode)
    lexical(given)
  end

  def lexical(node)
    [Hashira::Analysis::Syntax.new(node).segments, Hashira::Analysis::Syntax.new(node).rooted? ? [] : @nesting]
  end

  def root(node)
    return node if Hashira::Analysis::Syntax.new(node).static?
    root(node.receiver) if node.is_a?(Prism::CallNode)
  end
end
