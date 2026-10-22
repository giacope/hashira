# frozen_string_literal: true

class Hashira::Coupling::Territory
  def initialize(definitions)
    @definitions = definitions
  end

  def owned?(path) = owned.include?(path)

  private

  def owned = @_owned ||= named.select { claimed?(it) }.to_set(&:path)

  def named = @_named ||= @definitions.reject { it.path.empty? }

  def claimed?(definition)
    definition.created? || dependencies.own?(definition.scope.last) || !foreign?(root(definition))
  end

  def foreign?(root) = verdicts.fetch(root) { verdicts[root] = abroad?(root) }

  def verdicts = @_verdicts ||= {}

  def abroad?(root) = builtin?(root) || dependencies.foreign?(root) || !opened.include?(root)

  def builtin?(root) = Hashira::Analysis::CORE.include?(root) || Hashira::Analysis::LIBRARIES.include?(root.downcase)

  def opened
    @_opened ||= [
      *@definitions.select do
        defining?(it)
      end.map { it.scope.last }, *@definitions.implied, @definitions.prefix.first(1)
    ]
      .select(&:one?).to_set(&:first)
  end

  def defining?(definition)
    definition.created? || Hashira::Analysis::Syntax.new(definition.node).statements.any? { !autoload?(it) }
  end

  def autoload?(statement) = statement.is_a?(Prism::CallNode) && statement.name == :autoload

  def dependencies = @definitions.dependencies

  def root(definition) = definition.scope.last.first
end
