# frozen_string_literal: true

class Hashira::Listing
  TESTS = %w[test spec].freeze

  def initialize(files, skipped, paths)
    @files = files
    @skipped = skipped
    @paths = paths
  end

  def to_a = @files

  def sources(kept) = (@files | (kept & @skipped.values.flatten)).sort

  def skipped(told) = told.skipped(@files.size, @paths.to_s, @skipped)

  def located(shown) = (@_located ||= @files.to_h { [@paths.relative(it), File.expand_path(it)] }).fetch(shown)

  def test?(path) = (@_tests ||= @files.select { tested?(it) }.to_set).include?(path)

  private

  def tested?(path) = TESTS.include?(File.expand_path(path).delete_prefix("#{base(path)}/").split("/").first)

  def base(path)
    directory = File.expand_path(@paths.holder(path))
    File.exist?("#{directory}/config/application.rb") ? directory : File.dirname(directory)
  end
end
