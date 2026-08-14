# frozen_string_literal: true

require "prism"

class Hashira::Trees
  def initialize(project)
    @project = project
  end

  def all = @all ||= @project.files.to_h { [it, parse(it)] }

  def unparsed
    all
    @unparsed ||= []
  end

  private

  def parse(path)
    result = Prism.parse_file(path)
    (@unparsed ||= []) << path if result.failure?
    result.value
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
