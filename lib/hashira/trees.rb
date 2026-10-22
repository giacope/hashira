# frozen_string_literal: true

require "prism"

class Hashira::Trees
  REPLACED = { invalid: :replace, undef: :replace }.freeze

  def self.parse(path) = new(nil).tree(path)

  def initialize(project, kept = [])
    @project = project
    @kept = kept
  end

  def all = @_all ||= results.transform_values(&:value)

  def comments = results.transform_values(&:comments)

  def lines(path) = results.fetch(path).source.source.lines

  def unparsed = results.select { |_path, result| result.failure? }.keys

  def tree(path) = legible(parse(path)).value

  private

  def results = @_results ||= sources.to_h { [it, legible(parse(it))] }

  def sources = (@project.files | (@kept & @project.skipped.values.flatten)).sort

  def parse(path)
    Prism.parse_file(path)
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end

  def legible(result) = Prism.parse(result.source.source.encode(Encoding::UTF_8, **REPLACED), encoding: false)
end
