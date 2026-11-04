# frozen_string_literal: true

class Hashira::Coupling::Claims
  def initialize(opened, dependencies, spellings, builtins = Hashira::Runtime::Builtins.new)
    @opened = opened
    @dependencies = dependencies
    @spellings = spellings
    @builtins = builtins
  end

  def held?(scope) = @dependencies.own?(scope) || !(foreign?(scope.first) || claims?(scope))

  def core?(root) = @builtins.core?(root)

  private

  def claims?(scope) = @dependencies.claims?(scope) && !twin?(scope.first)

  def twin?(root) = @spellings.twin?(root, @opened)

  def foreign?(root) = verdicts.fetch(root) { verdicts[root] = abroad?(root) }

  def verdicts = @_verdicts ||= {}

  def builtin?(root) = core?(root) || @builtins.library?(root)

  def abroad?(root) = builtin?(root) || !@opened.include?(root) || (shipped?(root) && !twin?(root))

  def shipped?(root) = @dependencies.foreign?(root) || @spellings.required.include?(root)
end
