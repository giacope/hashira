# frozen_string_literal: true

class Hashira::Coupling::Territory
  def initialize(definitions, builtins = Hashira::Runtime::Builtins.new)
    @definitions = definitions
    @builtins = builtins
  end

  def owned?(path) = owned.include?(path)

  def outside?(path) = !path.empty? && !builtin?(path.first) && !owned?(path)

  private

  def owned = @_owned ||= @definitions.reject { it.path.empty? }.select { claimed?(it) }.to_set(&:path)

  def claimed?(definition)
    scope = definition.scope.last
    return false if definition.core?(@builtins)
    definition.created? || dependencies.own?(scope) || !(foreign?(scope.first) || claims?(scope))
  end

  def claims?(scope) = dependencies.claims?(scope) && !twin?(scope.first)

  def twin?(root) = spellings.twin?(root, opened)

  def foreign?(root) = verdicts.fetch(root) { verdicts[root] = abroad?(root) }

  def verdicts = @_verdicts ||= {}

  def builtin?(root) = @builtins.core?(root) || @builtins.library?(root)

  def abroad?(root) = builtin?(root) || !opened.include?(root) || (shipped?(root) && !twin?(root))

  def shipped?(root) = dependencies.foreign?(root) || spellings.required.include?(root)

  def opened
    @_opened ||=
      [*@definitions.filter_map { it.scope.last if defining?(it) }, *@definitions.implied, @definitions.prefix.first(1)]
        .select(&:one?).to_set(&:first)
  end

  def defining?(definition)
    definition.created? || Hashira::Analysis::Syntax::Body.new(definition.node).to_a.any? { !autoload?(it) }
  end

  def autoload?(statement) = statement.is_a?(Prism::CallNode) && statement.name == :autoload

  def dependencies = @_dependencies ||= @definitions.dependencies

  def spellings = @definitions.spellings
end
