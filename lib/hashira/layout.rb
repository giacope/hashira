# frozen_string_literal: true

class Hashira::Layout
  RAILS_TARGETS = %w[app lib].freeze

  def initialize(root = ".")
    @root = root
  end

  def targets
    return RAILS_TARGETS.select { Dir.exist?(placed(it)) } if File.exist?(placed("config/application.rb"))
    return required unless found("lib/*/").any? || found("lib/*.rb").any?
    libraries.empty? ? ["lib"] : libraries.map { "lib/#{it}" }
  end

  def suggestion(files) = ["hashira", *scope(files), "--only", files.join(",")].join(" ")

  private

  def scope(files) = read?(files) ? [] : tops(files)

  def read?(files) = files.all? { covered?(it) }

  def tops(files) = files.map { File.dirname(it).split("/").first }.uniq

  def covered?(file) = targets.any? { file.start_with?("#{it}/") }

  def required = found("*.gemspec").flat_map { Hashira::Gemspec.new(placed(it)).paths }.uniq

  def libraries
    @_libraries ||= found("lib/*.rb").map { File.basename(it, ".rb") }.select { Dir.exist?(placed("lib/#{it}")) }.sort
  end

  def placed(path) = File.join(@root, path)

  def found(pattern) = Dir.glob(pattern, base: @root)
end
