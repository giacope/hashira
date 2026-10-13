# frozen_string_literal: true

require "prism"

class Hashira::Trees
  def initialize(project)
    @project = project
  end

  def all = @_all ||= results.transform_values(&:value)

  def comments = results.transform_values(&:comments)

  def lines(path) = results.fetch(path).source.source.lines

  def unparsed = results.select { |_path, result| result.failure? }.keys

  private

  def results = @_results ||= @project.files.to_h { [it, parse(it)] }

  def parse(path)
    Prism.parse_file(path)
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
