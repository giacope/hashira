# frozen_string_literal: true

class Hashira::Project
  ROOT_PACKAGE = "(root)"

  def initialize(requested)
    @requested = requested
  end

  def directories = @_directories ||= resolved

  def rails? = directories.any? { config?(File.expand_path(it)) }

  def files = directories.flat_map { Dir["#{it}/**/*.rb"] }.sort

  def package(path)
    first, rest = relative(path).delete_suffix(".rb").split("/", 2)
    return ROOT_PACKAGE unless rest || folder?(path, first)
    contested.include?(first) ? "#{parent(path)}/#{first}" : first
  end

  def relative(path) = path.delete_prefix("#{parent(path)}/")

  def label = directories.join(", ")

  def root = ROOT_PACKAGE

  private

  def resolved
    chosen = (@requested.empty? ? defaults : @requested).map { descend(it.delete_suffix("/")) }
    vet(chosen)
    survivors = distinct(chosen)
    raise(Hashira::Error, "no Ruby files under #{survivors.join(", ")}") if bare?(survivors)
    survivors
  end

  def bare?(survivors) = survivors.flat_map { Dir["#{it}/**/*.rb"] }.empty?

  def defaults
    return ["lib"] if Dir["lib/*/"].any? || Dir["lib/*.rb"].any?
    raise(Hashira::Error, "no lib/ directory here — pass the source directory explicitly")
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
    file = directories.find { File.file?(it) }
    raise(Hashira::Error, "#{file} is a file — hashira takes directories (try: hashira #{File.dirname(file)})") if file
    missing = directories.reject { Dir.exist?(it) }
    raise(Hashira::Error, "no such directory: #{missing.join(", ")}") unless missing.empty?
  end

  def distinct(directories)
    pairs = directories.map { [it, File.realpath(it)] }.uniq(&:last)
    pairs.filter_map { |dir, path| dir unless nested?(path, pairs) }
  end

  def nested?(path, pairs) = pairs.any? { path.start_with?("#{it.last}/") }

  def config?(directory)
    ["config/application.rb", "../config/application.rb"].any? { File.exist?(File.expand_path(it, directory)) }
  end

  def folder?(path, name) = Dir.exist?("#{parent(path)}/#{name}")

  def contested
    @_contested ||=
      directories.flat_map { |directory| Dir["#{directory}/*/"].map { File.basename(it) } }
        .tally.filter_map { |name, count| name if count > 1 }
  end

  def parent(path)
    directories.find { path.start_with?("#{it}/") } ||
      raise(Hashira::Error, "#{path} is outside the analyzed directories")
  end
end
