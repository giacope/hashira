# frozen_string_literal: true

require "pathname"

class Hashira::Paths
  def initialize(directories, home)
    @directories = directories
    @home = home
  end

  def to_a = @directories

  def to_s = @directories.join(", ")

  def relative(path)
    home = holder(path)
    entry?(path, home) ? homeward(path) : "#{shown(home)}#{path.delete_prefix("#{home}/")}"
  end

  def expand(path) = File.expand_path(path, @home)

  def parse(path) = Hashira::Trees::Source.new(expand(path)).tree

  def holder(path)
    @directories.find { path.start_with?("#{it}/") || entry?(path, it) } ||
      raise(Hashira::Error, "#{path} is outside the analyzed directories")
  end

  private

  def shown(directory) = @directories.one? ? "" : "#{directory}/"

  def entry?(path, home) = path == "#{home}.rb"

  def homeward(path) = Pathname(File.expand_path(path)).relative_path_from(File.expand_path(@home)).to_s
end
