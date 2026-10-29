# frozen_string_literal: true

class Hashira::Coupling::Folders
  ROOT_PACKAGE = "(root)"

  def initialize(paths)
    @paths = paths
  end

  def package(path)
    home = @paths.holder(path)
    return "#{shown(home)}#{ROOT_PACKAGE}" if path == "#{home}.rb"
    first, rest = path.delete_prefix("#{home}/").delete_suffix(".rb").split("/", 2)
    return "#{shown(home)}#{ROOT_PACKAGE}" unless rest || Dir.exist?("#{home}/#{first}")
    contested.include?(first) ? "#{home}/#{first}" : first
  end

  def root = ROOT_PACKAGE

  private

  def shown(directory) = @paths.to_a.one? ? "" : "#{directory}/"

  def contested
    @_contested ||=
      @paths.to_a.flat_map { |directory| Dir["#{directory}/*/"].map { File.basename(it) } }
        .tally.filter_map { |name, count| name if count > 1 }
  end
end
