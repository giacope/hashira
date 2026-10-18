# frozen_string_literal: true

require "prism"

class Hashira::Trees
  REPLACED = { invalid: :replace, undef: :replace }.freeze

  def self.parse(path) = new(nil).tree(path)

  def initialize(project)
    @project = project
  end

  def all = @_all ||= results.transform_values(&:value)

  def comments = results.transform_values(&:comments)

  def lines(path) = results.fetch(path).source.source.lines

  def unparsed = results.select { |_path, result| result.failure? }.keys

  def tree(path) = legible(parse(path)).value

  private

  def results = @_results ||= @project.files.to_h { [it, legible(parse(it))] }

  def parse(path)
    Prism.parse_file(path)
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end

  def legible(result)
    text = result.source.source
    return result if text.encoding == Encoding::UTF_8 && text.valid_encoding?
    Prism.parse(text.encode(Encoding::UTF_8, **REPLACED), encoding: false)
  end
end
