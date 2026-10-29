# frozen_string_literal: true

class Hashira::Smells::ModuleInitialize < Hashira::Smells::Check
  ADVICE = "A mixin that carries constructor state is implementation inheritance; compose a collaborator instead."

  private

  def detail = Hashira::Smells::Spot.new(site, "defines initialize in a module", ADVICE)

  def smelly? = subject.kind == :module && subject.nodes.any?(Prism::ModuleNode) && !subject.singular? && flagged

  def flagged = subject.owned.any? { it.node.name == :initialize }
end
