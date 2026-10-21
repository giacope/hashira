# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Gift
  def initialize(call, nesting)
    @call = call
    @nesting = nesting
  end

  def to_a
    host = root(@call.receiver)
    Array(@call.arguments&.arguments).filter_map { offered(it) }.map { [*(host ? lexical(host) : [nil, []]), *it] }
  end

  private

  def offered(given)
    return ([@nesting.last, []] if @nesting.any?) if given.is_a?(Prism::SelfNode)
    lexical(given) if Hashira::Analysis::Syntax.static?(given)
  end

  def lexical(node)
    [Hashira::Analysis::Syntax.segments(node), Hashira::Analysis::Syntax.rooted?(node) ? [] : @nesting]
  end

  def root(node)
    return node if Hashira::Analysis::Syntax.static?(node)
    root(node.receiver) if node.is_a?(Prism::CallNode)
  end
end
