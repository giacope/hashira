# frozen_string_literal: true

class Hashira::Analysis::Naming
  def initialize(definitions)
    @segments = Hashira::Analysis::NamespacePrefix.infer(definitions)
  end

  attr_reader :segments

  def strip(path)
    return [] if @segments.first(path.length) == path
    path.drop(@segments.length.downto(0).find { path.first(it) == @segments.last(it) })
  end
end
