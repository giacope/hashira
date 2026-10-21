# frozen_string_literal: true

require "prism"

module Hashira::Coupling::Gift
  module_function

  def of(call, nesting)
    host = root(call.receiver)
    Array(call.arguments&.arguments).filter_map { offered(it, nesting) }
      .map { [*(host ? lexical(host, nesting) : [nil, []]), *it] }
  end

  def offered(given, nesting)
    return ([nesting.last, []] if nesting.any?) if given.is_a?(Prism::SelfNode)
    lexical(given, nesting) if Hashira::Analysis::Syntax.static?(given)
  end

  def lexical(node, nesting)
    [Hashira::Analysis::Syntax.segments(node), Hashira::Analysis::Syntax.rooted?(node) ? [] : nesting]
  end

  def root(node)
    return node if Hashira::Analysis::Syntax.static?(node)
    root(node.receiver) if node.is_a?(Prism::CallNode)
  end
end
