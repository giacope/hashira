# frozen_string_literal: true

class Hashira::Coupling::Outside
  EXTENSIONS = %w[
    .rb .rake .gemspec .ru .erb .haml .slim .builder .jbuilder .rabl .arb .yml .yaml .rbs .rbi .thor
  ].freeze

  NAMES = %w[Rakefile Gemfile Guardfile Capfile Thorfile Steepfile].freeze

  SCRIPTS = %w[bin exe].freeze

  SKIPPED = %w[vendor node_modules tmp log coverage].freeze

  LARGEST = 1_000_000

  WORD = /[A-Za-z_][A-Za-z0-9_]*[?!]?/

  LISTING = %w[ls-files -z --cached --others --exclude-standard].freeze

  def initialize(project)
    @project = project
  end

  def words = @_words ||= files.each_with_object(Set.new) { |path, found| read(path, found) }

  private

  def home = File.expand_path(@project.home)

  def files = listed.map { File.join(home, it) }.select { wanted?(it) }.reject { analyzed?(it) }

  def listed
    tracked = IO.popen(["git", "-C", home, *LISTING], err: File::NULL, &:read).split("\0")
    tracked.empty? ? walked : tracked
  rescue SystemCallError
    walked
  end

  def walked = Dir.glob("**/*", base: home).reject { SKIPPED.include?(it.split("/").first) }

  def wanted?(path) = known?(path) && File.file?(path) && File.size(path) <= LARGEST

  def known?(path)
    name = File.basename(path)
    EXTENSIONS.include?(File.extname(name)) || NAMES.include?(name) || script?(path)
  end

  def script?(path) = SCRIPTS.include?(File.basename(File.dirname(path)))

  def analyzed?(path) = path.end_with?(".rb") && places.any? { path.start_with?(it) }

  def places = @_places ||= @project.directories.map { "#{File.expand_path(it)}/" }

  def read(path, found)
    File.binread(path).scan(WORD) { found << it.force_encoding(Encoding::UTF_8) }
  end
end
