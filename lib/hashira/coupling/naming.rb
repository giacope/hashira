# frozen_string_literal: true

class Hashira::Coupling::Naming
  def initialize(definitions)
    @definitions = definitions
  end

  def segments = @segments ||= Hashira::Coupling::NamespacePrefix.infer(@definitions)

  def strip(path)
    return [] if segments.first(path.length) == path
    path.drop(segments.length.downto(0).find { path.first(it) == segments.last(it) })
  end
end
