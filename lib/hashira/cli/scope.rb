# frozen_string_literal: true

class Hashira::CLI::Scope
  def initialize(directories, skip, only, packaging)
    @directories = directories
    @skip = skip
    @only = only
    @packaging = packaging
  end

  def project(record, declared) = record.project(@directories, @packaging, declared)

  def pipeline(project, rules, layers, notices)
    scanned(notices, project.listing, project.paths)
    Hashira::Selection.build(@skip, @only).pipeline(project, rules, layers).verify
  end

  def narrowing? = !@only.empty?

  def to_h = { directories: @directories, skip: @skip, only: @only, packaging: @packaging }

  private

  def scanned(notices, listing, paths) = notices.scanning(listing.to_a.size, paths.to_s)
end
