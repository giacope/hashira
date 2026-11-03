# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bodies
  def sweep(type) = swept.fetch(type) { swept[type] = type.accept(Hashira::Smells::Scope).sweep }

  def passed(type, names) = calls(type).select { names.include?(it.name) }.flat_map { it.arguments.arguments }

  private

  def calls(type) = sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)

  def swept = @_swept ||= {}.compare_by_identity
end
