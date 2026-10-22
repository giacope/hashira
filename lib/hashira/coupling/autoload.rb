# frozen_string_literal: true

class Hashira::Coupling::Autoload
  NESTED = %w[concerns].freeze

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def roots = defined | namespaces

  def namespaces = @_namespaces ||= @project.rails? ? @trees.keys.flat_map { implied(it) }.to_set : Set.new

  private

  def defined = @trees.each_value.flat_map { fulls(it) }.to_set

  def fulls(tree) = Hashira::Analysis::TypeWalk.new(tree).to_enum(:walk).map { |_node, full| full }

  def implied(file)
    parts = file.split("/")
    at = parts.rindex("app")
    return [] unless at
    depth = at + 2
    depth += 1 if NESTED.include?(parts[depth])
    folders = parts[depth...-1] || []
    folders.each_index.map { |count| folders.first(count + 1).map { inflection.camelize(it) } }
  end

  def inflection
    @_inflection ||= Hashira::Coupling::Inflection.new(Hashira::Coupling::Inflections.of(@project.inflections))
  end
end
