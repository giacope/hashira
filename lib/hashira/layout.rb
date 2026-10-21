# frozen_string_literal: true

class Hashira::Layout
  RAILS_TARGETS = %w[app lib].freeze

  def targets
    return RAILS_TARGETS.select { Dir.exist?(it) } if File.exist?("config/application.rb")
    return required unless Dir["lib/*/"].any? || Dir["lib/*.rb"].any?
    libraries.empty? ? ["lib"] : libraries.map { "lib/#{it}" }
  end

  def suggestion(files) = ["hashira", *scope(files), "--only", files.join(",")].join(" ")

  private

  def scope(files) = read?(files) ? [] : tops(files)

  def read?(files) = files.all? { covered?(it) }

  def tops(files) = files.map { File.dirname(it).split("/").first }.uniq

  def covered?(file) = targets.any? { file.start_with?("#{it}/") }

  def required = Dir["*.gemspec"].flat_map { Hashira::Gemspec.new(it).paths }.uniq

  def libraries
    @_libraries ||= Dir["lib/*.rb"].map { File.basename(it, ".rb") }.select { Dir.exist?("lib/#{it}") }.sort
  end
end
