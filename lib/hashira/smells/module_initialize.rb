# frozen_string_literal: true

class Hashira::Smells::ModuleInitialize < Hashira::Smells::Check
  ADVICE = "A mixin that carries constructor state is implementation inheritance; compose a collaborator instead."

  private

  def detail = Hashira::Smells::Spot.new(site, "defines initialize in a module", ADVICE)

  def smelly? = !subject.first.seat.class? && modular? && !subject.bulk.singular? && flagged

  def modular? = subject.any? { it.accept(Hashira::Smells::Heading).module? }

  def flagged = owned.any? { selector(it) == :initialize }
end
