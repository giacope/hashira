# frozen_string_literal: true

class Hashira::Coupling::Affixes
  STEM = /\A[a-z_]\w*\z/

  NAMESPACE = /\A(?:[A-Z]\w*::)+\z/

  TAIL = /\A(?:_\w+|[A-Z]\w*)[?!=]?\z/

  def initialize(parts)
    @parts = parts
  end

  def to_a
    head, tail = [@parts.first, @parts.last].map { it.is_a?(Prism::StringNode) ? Hashira::Analysis::Syntax.new(it).text : "" }
    [(head if head.match?(STEM) || head.match?(NAMESPACE)).to_s, (tail if tail.length > 2 && tail.match?(TAIL)).to_s]
  end
end
