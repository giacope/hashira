# frozen_string_literal: true

class Hashira::Coupling::Territory
  def initialize(definitions)
    @definitions = definitions
  end

  def owned?(path) = owned.include?(path)

  def outside?(path) = !path.empty? && !builtin?(path.first) && !owned?(path)

  private

  def owned = @_owned ||= @definitions.reject { it.path.empty? }.select { claimed?(it) }.to_set(&:path)

  def claimed?(definition)
    scope = definition.scope.last
    return false if definition.core?
    definition.created? || dependencies.own?(scope) || !(foreign?(scope.first) || dependencies.claims?(scope))
  end

  def foreign?(root) = verdicts.fetch(root) { verdicts[root] = abroad?(root) }

  def verdicts = @_verdicts ||= {}

  def builtin?(root) = Hashira::Analysis::CORE.include?(root) || Hashira::Analysis::LIBRARIES.include?(root.downcase)

  def abroad?(root) = builtin?(root) || dependencies.foreign?(root) || !opened.include?(root)

  def opened
    @_opened ||=
      [*@definitions.filter_map { it.scope.last if defining?(it) }, *@definitions.implied, @definitions.prefix.first(1)]
        .select(&:one?).to_set(&:first)
  end

  def defining?(definition)
    definition.created? || Hashira::Analysis::Syntax.new(definition.node).statements.any? { !autoload?(it) }
  end

  def autoload?(statement) = statement.is_a?(Prism::CallNode) && statement.name == :autoload

  def dependencies = @definitions.dependencies
end
