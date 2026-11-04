# frozen_string_literal: true

class Hashira::Smells::Descent
  def initialize(openings)
    @openings = openings
  end

  def parent = first.map(&:parent).fetch(0, [])

  def parent? = first.any?

  private

  def first = Array(@openings.map { it.accept(Hashira::Smells::Heading) }.find { !it.written.empty? })
end
