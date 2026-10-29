# frozen_string_literal: true

class Hashira::Coupling::Naming
  def initialize(definitions, framework)
    @definitions = definitions
    @framework = framework
  end

  def to_a = @_to_a ||= engine.empty? ? Hashira::Coupling::NamespacePrefix.new(@definitions).infer : engine

  def rooted(path) = path.first(to_a.length) == to_a || to_a.first(path.length) == path ? [strip(path)] : []

  def strip(path)
    segments = to_a
    return [] if segments.first(path.length) == path
    path.drop(segments.length.downto(0).find { path.first(it) == segments.last(it) })
  end

  private

  def engine = @framework.engine.flat_map { it.split("::") }
end
