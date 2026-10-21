# frozen_string_literal: true

class Hashira::Project
  ROOT_PACKAGE = "(root)"

  INFLECTIONS = %w[config/initializers/inflections.rb ../config/initializers/inflections.rb].freeze

  TESTS = %w[test spec].freeze

  TEMPLATES = %r{/generators/(?:.+/)?templates/}

  def initialize(requested, boundaries: [], home: ".", rules: Hashira::Config::Rules::NONE)
    @requested = requested
    @boundaries = boundaries
    @home = home
    @rules = rules
  end

  attr_reader :boundaries, :home, :rules

  def directories = @_directories ||= resolved

  def rails? = application? || !engine.nil?

  def engine = (@_engine ||= [(engines.first if engines.one? && !application?)]).first

  def files = directories.flat_map { Dir["#{it}/**/*.rb"] }.grep_v(TEMPLATES).sort

  def package(path)
    home = parent(path)
    first, rest = path.delete_prefix("#{home}/").delete_suffix(".rb").split("/", 2)
    return "#{shown(home)}#{ROOT_PACKAGE}" unless rest || Dir.exist?("#{home}/#{first}")
    contested.include?(first) ? "#{home}/#{first}" : first
  end

  def relative(path)
    home = parent(path)
    "#{shown(home)}#{path.delete_prefix("#{home}/")}"
  end

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

  private

  def resolved
    chosen = distinct(named)
    survivors = chosen.one? ? [descend(chosen.first)] : chosen
    raise(Hashira::Error, "no Ruby files under #{survivors.join(", ")}") if bare?(survivors)
    survivors
  end

  def named
    chosen = (@requested.empty? ? defaults : @requested).map { tidy(it) }
    vet(chosen)
    chosen
  end

  def tidy(path) = path.delete_suffix("/").delete_prefix("#{Dir.pwd}/").delete_prefix("./")

  def bare?(survivors) = survivors.flat_map { Dir["#{it}/**/*.rb"] }.empty?

  def defaults
    found = Hashira::Layout.new.targets
    raise(Hashira::Error, "no lib/ directory here — pass the source directory explicitly") if found.empty?
    found
  end

  def descend(directory)
    child = sole(directory)
    return directory unless child && Dir["#{child}/*/"].any? && (Dir["#{directory}/*.rb"] - ["#{child}.rb"]).empty?
    descend(child)
  end

  def sole(directory)
    subdirectories = Dir["#{directory}/*/"]
    subdirectories.size == 1 ? subdirectories.first.delete_suffix("/") : nil
  end

  def vet(directories)
    files = directories.select { File.file?(it) }
    raise(Hashira::Error, "#{files.first} is a file — hashira takes directories (try: #{hint(files)})") if files.any?
    missing = directories.reject { Dir.exist?(it) }
    raise(Hashira::Error, "no such directory: #{missing.join(", ")}") unless missing.empty?
  end

  def hint(files) = Hashira::Layout.new.suggestion(files)

  def distinct(directories)
    pairs = directories.map { [it, File.realpath(it)] }.uniq(&:last)
    pairs.filter_map { |dir, path| dir unless nested?(path, pairs) }
  end

  def nested?(path, pairs) = pairs.any? { path.start_with?("#{it.last}/") }

  def application? = directories.any? { config?(File.expand_path(it)) }

  def engines = directories.flat_map { Dir["#{it}/**/engine.rb"] }.filter_map { Hashira::Engine.namespace(it) }.uniq

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
    directories.find { path.start_with?("#{it}/") } ||
      raise(Hashira::Error, "#{path} is outside the analyzed directories")
  end
end
