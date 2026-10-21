# frozen_string_literal: true

class Hashira::Dependencies
  LOCKED = /^ {4}([^\s(]+) \(/

  SECTION = /^(?=[A-Z])/

  GEMFILE = /^\s*gem\s*\(?\s*["']([^"'\s]+)["']/

  DECLARED = /\.add_(?:runtime_|development_)?dependency\s*\(?\s*["']([^"'\s]+)["']/

  GEMSPECS = %w[*.gemspec */*.gemspec].freeze

  def initialize(home)
    @home = home
  end

  def foreign?(root) = foreign.include?(plain(root))

  def own?(path)
    words = path.map { plain(it) }
    mine.any? { words.first(it.size) == it }
  end

  private

  def foreign = @_foreign ||= (named - mine).to_set(&:first) - mine.select(&:one?).map(&:first)

  def named
    listed = read("Gemfile").scan(GEMFILE) + gemspecs.flat_map { File.read(it).scan(DECLARED) }
    (locked.values_at("GEM", "GIT").compact + listed).flatten.uniq.map { camel(it) }
  end

  def mine
    @_mine ||= (gemspecs.map { File.basename(it, ".gemspec") } + locked.fetch("PATH", [])).uniq.map { camel(it) }
  end

  def camel(name) = name.split("-").map { plain(it) }

  def plain(name) = name.downcase.delete("_")

  def locked
    @_locked ||=
      read("Gemfile.lock").split(SECTION).group_by { it[/\A\S+/] }
        .transform_values { |blocks| blocks.flat_map { it.scan(LOCKED).flatten } }
  end

  def gemspecs = @_gemspecs ||= GEMSPECS.flat_map { Dir.glob(File.join(@home, it)) }.sort

  def read(name)
    path = File.join(@home, name)
    File.file?(path) ? File.read(path) : ""
  end
end
