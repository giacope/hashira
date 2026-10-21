# frozen_string_literal: true

module Hashira::Coupling::Affixes
  STEM = /\A[a-z_]\w*\z/

  NAMESPACE = /\A(?:[A-Z]\w*::)+\z/

  TAIL = /\A(?:_\w+|[A-Z]\w*)[?!=]?\z/

  module_function

  def of(parts)
    head, tail = [parts.first, parts.last].map { it.is_a?(Prism::StringNode) ? Hashira::Analysis::Syntax.text(it) : "" }
    [(head if head.match?(STEM) || head.match?(NAMESPACE)).to_s, (tail if tail.length > 2 && tail.match?(TAIL)).to_s]
  end
end
