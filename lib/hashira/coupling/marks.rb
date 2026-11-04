# frozen_string_literal: true

class Hashira::Coupling::Marks
  def initialize(evaluated, opened, reflection)
    @evaluated = evaluated
    @opened = opened
    @reflection = reflection
  end

  def evaluated?(name) = @evaluated.include?(name.split("::")[...-1])

  def opened?(path) = @opened.include?(path)

  def reached?(path) = @reflection.reached?(path)
end
