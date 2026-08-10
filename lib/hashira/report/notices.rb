# frozen_string_literal: true

class Hashira::Report::Notices
  def initialize(pipeline, io: $stderr)
    @pipeline = pipeline
    @io = io
  end

  def print
    return if @pipeline.churn.history?
    @io.puts("hashira: no git history for #{@pipeline.project.label} — hotspots are ranked by cost alone")
  end
end
