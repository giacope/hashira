# frozen_string_literal: true

require "pathname"

class Hashira::CLI::Home
  OWN = %w[.hashira.yml hashira_baseline.json].freeze

  MARKERS = %w[.git Gemfile *.gemspec].freeze

  LAYOUT = %w[lib config/application.rb].freeze

  def self.build(directories) = new(directories, Dir.pwd)

  def initialize(directories, here)
    @directories = directories
    @here = here
  end

  def path = @_path ||= @directories.empty? ? @here : found

  def join(name) = path == @here ? name : File.join(path, name)

  def expand(name) = path == @here ? name : File.expand_path(name, path)

  def relative(target) = Pathname(File.expand_path(target)).relative_path_from(Pathname(path)).to_s

  private

  def start = File.expand_path(@directories.first)

  def found = ancestors.find { rooted?(it) } || climb(LAYOUT) || start

  def rooted?(directory) = directory == @here || holds?(directory, OWN + MARKERS)

  def climb(names) = ancestors.find { holds?(it, names) }

  def holds?(directory, names) = names.any? { Dir.glob(it, base: directory).any? }

  def ancestors = Pathname(start).ascend.map(&:to_s)
end

Hashira::CLI::Home::HERE = Hashira::CLI::Home.new([], ".")
