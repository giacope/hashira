# frozen_string_literal: true

class Hashira::Dependencies
  LOCKED = /^ {4}([^\s(]+) \(/

  SECTION = /^(?=[A-Z])/

  GEMFILE = /^\s*gem\s*\(?\s*["']([^"'\s]+)["']/

  REQUIRED = /^\s*gem\s*\(?\s*["'][^"'\s]+["'][^#\n]*\brequire:\s*["']([^"'\s]+)["']/

  DECLARED = /\.add_(?:runtime_|development_)?dependency\s*\(?\s*["']([^"'\s]+)["']/

  GEMSPECS = %w[*.gemspec */*.gemspec].freeze

  def initialize(home)
    @home = home
  end

  def foreign?(root) = foreign.include?(plain(root))

  def own?(path) = within?(mine, path)

  def claims?(path) = within?(others, path)

  private

  def within?(names, path)
    words = path.map { plain(it) }
    names.any? { words.first(it.size) == it }
  end

  def foreign = @_foreign ||= others.select(&:one?).to_set(&:first)

  def others = @_others ||= named - mine

  def named = (listed.map { camel(it) } + required).uniq

  def listed
    declared = read("Gemfile").scan(GEMFILE) + gemspecs.flat_map { File.read(it).scan(DECLARED) }
    (locked.values_at("GEM", "GIT").compact + declared).flatten
  end

  def required = read("Gemfile").scan(REQUIRED).flatten.map { camel(it.tr("/", "-")) }

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
