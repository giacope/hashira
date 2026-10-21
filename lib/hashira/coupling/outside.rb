# frozen_string_literal: true

class Hashira::Coupling::Outside
  EXTENSIONS = %w[
    .rb .rake .gemspec .ru .erb .haml .slim .builder .jbuilder .rabl .arb .yml .yaml .json .rbs .rbi .thor .tt
  ].freeze

  NAMES = %w[Rakefile Gemfile Guardfile Capfile Thorfile Steepfile].freeze

  SCRIPTS = %w[bin exe].freeze

  SKIPPED = %w[vendor node_modules tmp log coverage].freeze

  LARGEST = 1_000_000

  WORD = /[A-Za-z_][A-Za-z0-9_]*[?!]?/

  MATCHERS = { "be" => "%s?", "have" => "has_%s?" }.freeze

  MATCHER = /\A(be|have)_(?:an?_)?([a-z]\w*)\z/

  SPECS = %r{\A(?!.*/factories/)(?:.*/)?(?:spec|test)/|_(?:spec|test)\.rb\z}

  DOCS = %r{\A(?:docs?/.*\.md|README[^/]*)\z}

  HANDED = /\.(?:include|prepend|extend|register\w*)[(\s]\s*((?:::)?[A-Z]\w*(?:::[A-Z]\w*)*)/

  LISTING = %w[ls-files -z --cached --others --exclude-standard].freeze

  def initialize(project)
    @project = project
  end

  def words = scanned.first

  def handed = scanned.last

  private

  def scanned = @_scanned ||= files.each_with_object([Set.new, Set.new]) { |path, found| read(path, *found) }

  def home = File.expand_path(@project.home)

  def files = listed.map { File.join(home, it) }.select { wanted?(it) }.reject { analyzed?(it) }

  def spec?(path) = path.end_with?(".rb") && path.delete_prefix("#{home}/").match?(SPECS)

  def called(path, words) = words.merge(Hashira::Coupling::SpecWords.new(@project.tree(path)).to_a)

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
    EXTENSIONS.include?(File.extname(name)) || NAMES.include?(name) || script?(path) || doc?(path)
  end

  def doc?(path) = gem? && path.delete_prefix("#{home}/").match?(DOCS)

  def gem? = (@_gem ||= [Dir.glob("*.gemspec", base: home).any?]).first

  def script?(path) = SCRIPTS.include?(File.basename(File.dirname(path)))

  def analyzed?(path) = analyzed.include?(path)

  def analyzed = @_analyzed ||= @project.files.to_set { File.expand_path(it) }

  def read(path, words, handed)
    text = File.binread(path)
    spec?(path) ? called(path, words) : text.scan(WORD) { words << it.force_encoding(Encoding::UTF_8) }
    text.scan(HANDED).flatten.each { handed << it.delete_prefix("::").force_encoding(Encoding::UTF_8).split("::") }
  end
end
