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

  RUBY = ".rb"

  def initialize(project)
    @project = project
  end

  def words = scanned.first

  def handed = scanned.last

  private

  def scanned = @_scanned ||= gathered

  def gathered
    words = Set.new
    handed = Set.new
    files.each do |path|
      seen, given = read(path)
      words.merge(seen)
      handed.merge(given)
    end
    [words, handed]
  end

  def home = File.expand_path(@project.home)

  def files = listed.map { File.join(home, it) }.select { wanted?(it) }.reject { analyzed?(it) }

  def spec?(path) = path.end_with?(RUBY) && path.delete_prefix("#{home}/").match?(SPECS)

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

  def read(path)
    text = File.binread(path)
    tree = (@project.tree(path) if path.end_with?(RUBY))
    [spec?(path) ? Hashira::Coupling::SpecWords.new(tree).to_a : said(text), given(text) + hooks(tree)]
  end

  def said(text) = text.scan(WORD).map { it.force_encoding(Encoding::UTF_8) }

  def given(text) = text.scan(HANDED).flatten.map { it.delete_prefix("::").force_encoding(Encoding::UTF_8).split("::") }

  def hooks(tree)
    calls = [tree].compact.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }.grep(Prism::CallNode)
    calls.flat_map { Hashira::Coupling::Hand.new(it).loaded }.flat_map { Hashira::Coupling::Hand.new(it).given }
  end
end
