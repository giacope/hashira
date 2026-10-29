# frozen_string_literal: true

require "prism"

class Hashira::Trees
  class Source
    REPLACED = { invalid: :replace, undef: :replace }.freeze

    def initialize(path)
      @path = path
    end

    def result = Prism.parse(read(@path).source.source.encode(Encoding::UTF_8, **REPLACED), encoding: false)

    def tree = result.value

    private

    def read(path)
      Prism.parse_file(path)
    rescue SystemCallError => error
      raise(Hashira::Error, "cannot read #{path} (#{error.message})")
    end
  end

  def initialize(project, kept = [])
    @project = project
    @kept = kept
  end

  def all = @_all ||= results.transform_values(&:value)

  def comments = results.transform_values(&:comments)

  def lines(path) = results.fetch(path).source.source.lines

  def unparsed = results.select { |_path, result| result.failure? }.keys

  def tree(path) = Hashira::Trees::Source.new(path).tree

  private

  def results = @_results ||= sources.to_h { [it, Hashira::Trees::Source.new(it).result] }

  def sources = (@project.files | (@kept & @project.skipped.values.flatten)).sort
end
