# frozen_string_literal: true

require "prism"

module Hashira
  class Pipeline
    def initialize(project)
      @project = project
      trees = project.files.to_h { [it, parse(it)] }
      @census = Analysis::Census.new(project, trees)
      @graph = Analysis::Graph.new(project, trees, @census)
    end

    attr_reader :project, :graph

    RULES = [Analysis::CycleFindings, Analysis::SdpViolationFindings].freeze

    def findings = RULES.flat_map { it.new(@project, @graph).list }

    private

    def parse(path)
      Prism.parse_file(path).value
    rescue SystemCallError => error
      raise Error, "cannot read #{path} (#{error.message})"
    end
  end
end
