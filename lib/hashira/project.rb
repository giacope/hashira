# frozen_string_literal: true

module Hashira
  class Project
    ROOT_PACKAGE = "(root)"

    def self.detect(directories)
      return new(directories) unless directories.empty?

      subdirectories = Dir["lib/*/"].map { File.basename(_1) }
      raise Error, "no lib/ directory here — pass the source directory explicitly" if subdirectories.empty?

      new(subdirectories.size == 1 ? ["lib/#{subdirectories.first}"] : ["lib"])
    end

    def initialize(directories)
      missing = directories.reject { Dir.exist?(_1) }
      raise Error, "no such directory: #{missing.join(", ")}" unless missing.empty?

      @directories = directories.map { _1.delete_suffix("/") }
    end

    attr_reader :directories

    def files = @directories.flat_map { Dir["#{_1}/**/*.rb"] }.sort

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
      @directories.find { path.start_with?("#{_1}/") } ||
        raise(Error, "#{path} is outside the analyzed directories")
    end
  end
end
