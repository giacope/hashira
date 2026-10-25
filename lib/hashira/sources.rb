# frozen_string_literal: true

class Hashira::Sources
  TEMPLATES = %r{/generators/(?:.+/)?\w*templates?/|(?:\A|/)lib/templates/}

  COPIED = /\A(?:templates|\w+_template)\z/

  PROJECT_FILES = "**/{*.erb,*.tt,Gemfile,*gemspec,Rakefile}"

  LIB = "lib"

  GRAMMARS = %w[.rl .y .racc .treetop .rex].freeze

  GENERATED = /
    \bgenerated\s+(?:by|from)\b|(?<![\w@])@generated\b|\bauto-?generated\b|\ba\s+generated\s+file\b|
    \bdo\s+not\s+(?:edit|modify)\b|\bhas\s+been\s+generated\b
  /ix

  COMMENT = /\A\s*(?:#|\z)/

  VENDOR = "vendor"

  def initialize(directories, entries: [])
    @directories = directories
    @entries = entries
  end

  def files = @_files ||= found - skipped.values.flatten

  def skipped = @_skipped ||= found.group_by { reason(it) }.except(nil)

  private

  def found = @_found ||= (@directories.flat_map { Dir["#{it}/**/*.rb"] } + @entries).uniq.grep_v(TEMPLATES).sort

  def reason(path)
    return :vendored if folders(path).include?(VENDOR)
    return :template if template?(path)
    :generated if generated?(path)
  end

  def folders(path) = path.delete_prefix("#{home(path)}/").split("/")[...-1]

  def home(path) = @directories.find { path.start_with?("#{it}/") }

  def template?(path)
    below = folders(path)
    index = below.index { it.match?(COPIED) } or return false
    copied = [*home(path).to_s.split("/"), *below[..index]]
    copied.include?(LIB) && Dir.glob(PROJECT_FILES, base: copied.join("/")).any?
  end

  def generated?(path) = GRAMMARS.any? { File.exist?(path.delete_suffix(".rb") + it) } || head(path).match?(GENERATED)

  def head(path)
    File.file?(path) ? File.open(path, "rb") { |io| io.each_line.take_while { it.match?(COMMENT) }.join } : ""
  end
end
