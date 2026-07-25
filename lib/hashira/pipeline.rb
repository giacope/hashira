# frozen_string_literal: true

require "prism"

module Hashira
  class Pipeline
    ANALYZERS = %i[coupling complexity duplication].freeze

    RULES = [Analysis::CycleFindings, Analysis::SdpViolationFindings].freeze

    def initialize(project, enabled: ANALYZERS)
      @project = project
      @enabled = enabled
      @trees = project.files.to_h { [it, parse(it)] }
      @graph = Analysis::Graph.new(project, @trees, Analysis::Census.new(project, @trees))
    end

    attr_reader :project, :graph

    def complexity
      @complexity ||= Complexity::Analyzer.new(@project, @trees) if enabled?(:complexity)
    end

    def duplication
      @duplication ||= Duplication::Analyzer.new(@project, @trees, churn) if enabled?(:duplication)
    end

    def hotspots
      @hotspots ||= Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
    end

    def churn = @churn ||= Churn.from_git

    def enabled?(analyzer) = @enabled.include?(analyzer)

    def findings = coupling_findings + listed(complexity) + listed(duplication)

    private

    def coupling_findings = enabled?(:coupling) ? RULES.flat_map { it.new(@project, @graph).list } : []

    def listed(analyzer) = analyzer ? analyzer.findings : []

    def parse(path)
      Prism.parse_file(path).value
    rescue SystemCallError => error
      raise Error, "cannot read #{path} (#{error.message})"
    end
  end
end
