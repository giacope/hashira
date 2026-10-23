# frozen_string_literal: true

require "pathname"

class Hashira::Project
  ROOT_PACKAGE = "(root)"

  INFLECTIONS = %w[config/initializers/inflections.rb ../config/initializers/inflections.rb].freeze

  TESTS = %w[test spec].freeze

  def initialize(requested, boundaries: [], home: ".", rules: Hashira::Config::Rules::NONE)
    @requested = requested
    @boundaries = boundaries
    @home = home
    @rules = rules
  end

  attr_reader :boundaries, :home, :rules

  def directories = @_directories ||= resolution.resolved

  def rails? = application? || !engine.nil?

  def engine = (@_engine ||= [(engines.first if engines.one? && !application?)]).first

  def files = sources.files

  def skipped = sources.skipped

  def scope = [files.size, label, skipped]

  def tree(path) = parser.tree(path)

  def package(path)
    home = parent(path)
    return "#{shown(home)}#{ROOT_PACKAGE}" if entry?(path, home)
    first, rest = path.delete_prefix("#{home}/").delete_suffix(".rb").split("/", 2)
    return "#{shown(home)}#{ROOT_PACKAGE}" unless rest || Dir.exist?("#{home}/#{first}")
    contested.include?(first) ? "#{home}/#{first}" : first
  end

  def relative(path)
    home = parent(path)
    entry?(path, home) ? homeward(path) : "#{shown(home)}#{path.delete_prefix("#{home}/")}"
  end

  def located(shown) = (@_located ||= files.to_h { [relative(it), File.expand_path(it)] }).fetch(shown)

  def test?(path) = (@_tests ||= files.select { tested?(it) }.to_set).include?(path)

  def shown(directory) = directories.one? ? "" : "#{directory}/"

  def label = directories.join(", ")

  def inflections
    found = directories.flat_map { |directory| INFLECTIONS.map { File.expand_path(it, directory) } }
    Hashira::Trees.parse(found.find { File.file?(it) } || return)
  end

  def root = ROOT_PACKAGE

  def history = @_history ||= Hashira::GitLog.new(self)

  def layers = rules.layers

  def dependencies = @_dependencies ||= Hashira::Dependencies.new(home)

  private

  def parser = @_parser ||= Hashira::Trees.new(self)

  def resolution = @_resolution ||= Hashira::Directories.new(@requested)

  def sources = @_sources ||= Hashira::Sources.new(directories, entries: resolution.entries(directories))

  def entry?(path, home) = path == "#{home}.rb"

  def homeward(path) = Pathname(File.expand_path(path)).relative_path_from(File.expand_path(@home)).to_s

  def application? = directories.any? { config?(File.expand_path(it)) }

  def engines = Hashira::Engine.new(directories, home).namespaces

  def config?(directory)
    ["config/application.rb", "../config/application.rb"].any? { File.exist?(File.expand_path(it, directory)) }
  end

  def contested
    @_contested ||=
      directories.flat_map { |directory| Dir["#{directory}/*/"].map { File.basename(it) } }
        .tally.filter_map { |name, count| name if count > 1 }
  end

  def tested?(path) = TESTS.include?(File.expand_path(path).delete_prefix("#{base(path)}/").split("/").first)

  def base(path)
    directory = File.expand_path(parent(path))
    File.exist?("#{directory}/config/application.rb") ? directory : File.dirname(directory)
  end

  def parent(path)
    directories.find { path.start_with?("#{it}/") || entry?(path, it) } ||
      raise(Hashira::Error, "#{path} is outside the analyzed directories")
  end
end
