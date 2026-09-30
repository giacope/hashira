# frozen_string_literal: true

class Hashira::Coupling::Territory
  def initialize(definitions)
    @definitions = definitions
  end

  def owned?(path) = owned.include?(path)

  private

  def owned = @_owned ||= named.select { claimed?(it) }.to_set(&:path)

  def named = @_named ||= @definitions.reject { it.path.empty? }

  def claimed?(definition) = definition.created? || !foreign?(root(definition))

  def foreign?(root) = verdicts[root]

  def verdicts = @_verdicts ||= Hash.new { |known, root| known[root] = abroad?(root) }

  def abroad?(root) = Hashira::Coupling::Builtin.include?(root) || !(homes.include?(root) || founded.include?(root))

  def founded = @_founded ||= @definitions.select { it.klass? && it.created? }.to_set { root(it) }

  def homes = @_homes ||= named.select { home?(it) }.to_set { root(it) }

  def home?(definition) = places(definition.file).include?(plain(root(definition)))

  def places(file) = file.delete_suffix(".rb").split("/").map { plain(it) }

  def root(definition) = definition.scope.last.first

  def plain(name) = name.downcase.delete("_")
end
