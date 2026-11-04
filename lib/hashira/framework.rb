# frozen_string_literal: true

class Hashira::Framework
  INFLECTIONS = %w[config/initializers/inflections.rb ../config/initializers/inflections.rb].freeze

  CONFIGURED = %w[config/application.rb ../config/application.rb].freeze

  def initialize(directories, engines, packaging)
    @directories = directories
    @engines = engines
    @packaging = packaging
  end

  def rails? = application? || engine.any?

  def engine = @engines.one? && !application? ? @engines : []

  def inflection = Hashira::Coupling::Inflection.new(Hashira::Coupling::Inflections.of(inflections))

  def packaging
    return @packaging unless @packaging == :auto
    rails? ? :namespace : :folder
  end

  private

  def inflections
    found = @directories.flat_map { |directory| INFLECTIONS.map { File.expand_path(it, directory) } }
    found.select { File.file?(it) }.first(1).map { Hashira::Trees::Source.new(it).tree }
  end

  def application? = (@_application ||= [configured?]).first

  def configured? = @directories.any? { |directory| CONFIGURED.any? { File.exist?(File.expand_path(it, directory)) } }
end
