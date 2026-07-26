# frozen_string_literal: true

module Hashira
  class Project
    ROOT_PACKAGE = "(root)"

    def self.detect(directories)
      targets = directories.empty? ? default_directories : directories
      new(targets.map { descend(it.delete_suffix("/")) })
    end

    def self.default_directories
      raise Error, "no lib/ directory here — pass the source directory explicitly" if Dir["lib/*/"].empty?

      ["lib"]
    end
    private_class_method :default_directories

    def self.descend(directory)
      child = only_subdirectory(directory)
      return directory unless child && Dir["#{child}/*/"].any? && (Dir["#{directory}/*.rb"] - ["#{child}.rb"]).empty?

      descend(child)
    end

    def self.only_subdirectory(directory)
      subdirectories = Dir["#{directory}/*/"]
      subdirectories.size == 1 ? subdirectories.first.delete_suffix("/") : nil
    end
    private_class_method :descend, :only_subdirectory

    def initialize(directories)
      missing = directories.reject { Dir.exist?(it) }
      raise Error, "no such directory: #{missing.join(", ")}" unless missing.empty?

      @directories = directories.map { it.delete_suffix("/") }
    end

    attr_reader :directories

    def files = @directories.flat_map { Dir["#{it}/**/*.rb"] }.sort

    def package_for(path)
      first, rest = relative(path).delete_suffix(".rb").split("/", 2)
      return ROOT_PACKAGE unless rest || folder?(path, first)

      contested.include?(first) ? "#{directory_of(path)}/#{first}" : first
    end

    def relative(path) = path.delete_prefix("#{directory_of(path)}/")

    def label = @directories.join(", ")

    def root_package = ROOT_PACKAGE

    private

    def folder?(path, name) = Dir.exist?("#{directory_of(path)}/#{name}")

    def contested
      @contested ||= @directories.flat_map { |directory| Dir["#{directory}/*/"].map { File.basename(it) } }
                                 .tally.filter_map { |name, count| name if count > 1 }
    end

    def directory_of(path)
      @directories.find { path.start_with?("#{it}/") } ||
        raise(Error, "#{path} is outside the analyzed directories")
    end
  end
end
