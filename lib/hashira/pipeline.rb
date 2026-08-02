# frozen_string_literal: true

require "prism"

class Hashira::Pipeline
  ANALYZERS = %i[coupling complexity duplication smells].freeze

  RULES = [Hashira::Analysis::CycleFindings, Hashira::Analysis::SdpViolationFindings].freeze

  def initialize(project, enabled: ANALYZERS, packaging: :auto)
    @project = project
    @enabled = enabled
    @trees = project.files.to_h { [it, parse(it)] }
    @graph = Hashira::Analysis::Graph.new(project, @trees, census(settle(packaging)))
  end

  attr_reader :project, :graph

  def complexity
    @complexity ||= Hashira::Complexity::Analyzer.new(@project, @trees) if enabled?(:complexity)
  end

  def duplication
    @duplication ||= Hashira::Duplication::Analyzer.new(@project, @trees, churn) if enabled?(:duplication)
  end

  def smells
    @smells ||= Hashira::Smells::Analyzer.new(@project, @trees) if enabled?(:smells)
  end

  def hotspots
    @hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @churn ||= Hashira::Churn.scan

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def findings = structural + listed(complexity) + listed(duplication) + listed(smells)

  private

  def census(packaging) = Hashira::Analysis::Census.new(@project, @trees, packaging:)

  def settle(packaging)
    return packaging unless packaging == :auto
    @project.rails? ? :namespace : :folder
  end

  def structural = enabled?(:coupling) ? RULES.flat_map { it.new(@project, @graph).list } : []

  def listed(analyzer) = analyzer ? analyzer.findings : []

  def parse(path)
    Prism.parse_file(path).value
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
