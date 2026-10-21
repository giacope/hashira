# frozen_string_literal: true

class Hashira::Directories
  def initialize(requested)
    @requested = requested
  end

  def entries(directories)
    named = @requested.map { "#{tidy(it)}/" }
    directories.map { "#{it}.rb" }.select do |entry|
      File.file?(entry) && (
        named.empty? || named.any? do
          entry.start_with?(it)
        end
      )
    end
  end

  def resolved
    chosen = distinct(named)
    survivors = chosen.one? ? [descend(chosen.first)] : chosen
    raise(Hashira::Error, "no Ruby files under #{survivors.join(", ")}") if bare?(survivors)
    survivors
  end

  private

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
end
