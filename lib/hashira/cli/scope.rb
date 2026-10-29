# frozen_string_literal: true

class Hashira::CLI::Scope
  def initialize(directories, skip, only, packaging)
    @directories = directories
    @skip = skip
    @only = only
    @packaging = packaging
  end

  def pipeline(judgement, record, notices, checks = Hashira::Checks.new)
    project = judgement.project(@directories, record)
    notices.scanning(project.files.size, project.label)
    Hashira::Pipeline.new(project, enabled: checks.analyzers - @skip, packaging: @packaging, only: @only).verify
  end

  def to_h = { directories: @directories, skip: @skip, only: @only, packaging: @packaging }
end
