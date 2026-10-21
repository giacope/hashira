# frozen_string_literal: true

class Hashira::Coupling::Naming
  def initialize(definitions)
    @definitions = definitions
  end

  def segments
    @_segments ||= @definitions.engine.then { it.empty? ? Hashira::Coupling::NamespacePrefix.infer(@definitions) : it }
  end

  def rooted(path) = (strip(path) if path.first(segments.length) == segments || segments.first(path.length) == path)

  def strip(path)
    return [] if segments.first(path.length) == path
    path.drop(segments.length.downto(0).find { path.first(it) == segments.last(it) })
  end
end
