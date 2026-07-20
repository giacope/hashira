# frozen_string_literal: true

module Hashira
  class Project
    ROOT_PACKAGE = "(root)"

    def self.detect(directories)
      directories.empty? ? new(default_directories) : new(directories)
    end

    def self.default_directories
      subdirectories = Dir["lib/*/"].map { File.basename(it) }
      raise Error, "no lib/ directory here — pass the source directory explicitly" if subdirectories.empty?

      subdirectories.size == 1 ? ["lib/#{subdirectories.first}"] : ["lib"]
    end
    private_class_method :default_directories

    def initialize(directories)
      missing = directories.reject { Dir.exist?(it) }
      raise Error, "no such directory: #{missing.join(", ")}" unless missing.empty?

      @directories = directories.map { it.delete_suffix("/") }
    end

    attr_reader :directories

    def files = @directories.flat_map { Dir["#{it}/**/*.rb"] }.sort

    def package_for(path)
      first, rest = relative(path).delete_suffix(".rb").split("/", 2)
      rest || folder?(path, first) ? first : ROOT_PACKAGE
    end

    def relative(path) = path.delete_prefix("#{directory_of(path)}/")

    def label = @directories.join(", ")

    def root_package = ROOT_PACKAGE

    private

    def folder?(path, name) = Dir.exist?("#{directory_of(path)}/#{name}")

    def directory_of(path)
      @directories.find { path.start_with?("#{it}/") } ||
        raise(Error, "#{path} is outside the analyzed directories")
    end
  end
end
