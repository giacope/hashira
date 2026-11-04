# frozen_string_literal: true

class Hashira::Coupling::Site
  def initialize(path, scope, file)
    @path = path
    @scope = scope
    @file = file
  end

  def to_s = @file

  def top? = @scope.one?

  def nested? = @path.length > 1

  def nestings(segments) = [*@scope[...-1].reverse.map { it + segments }, segments]
end
