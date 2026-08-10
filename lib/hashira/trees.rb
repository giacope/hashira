# frozen_string_literal: true

require "prism"

class Hashira::Trees
  def initialize(project)
    @unparsed = []
    @all = project.files.to_h { [it, parse(it)] }
  end

  attr_reader :all, :unparsed

  private

  def parse(path)
    result = Prism.parse_file(path)
    @unparsed << path if result.failure?
    result.value
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
