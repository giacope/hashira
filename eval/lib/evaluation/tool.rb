# frozen_string_literal: true

class Evaluation::Tool
  HOME = Evaluation::Home.new

  PEAK = HOME.join("probe", "peak.rb")

  EVERY = HOME.join("probe", "every.yml")

  QUIET = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT RUBYLIB].to_h { [it, nil] }.freeze

  def self.build(root) = new(File.expand_path(root))

  def initialize(root, scratch = Dir)
    @root = root
    @scratch = scratch
  end

  def call(directory, arguments)
    @scratch.mktmpdir("peak") { |scratch| run(directory, arguments, File.join(scratch, "peak")) }
  end

  def configure(settings, path)
    return unless settings
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump({ "checks" => "all" }.merge(settings)))
  end

  def arguments(settings, path) = settings ? ["--config", path] : every

  def commit = Open3.capture2e("git", "-C", @root, "rev-parse", "--short", "HEAD").first.strip

  private

  def every = @_every ||= opting? ? ["--config", EVERY] : []

  def run(directory, arguments, report)
    output, error, status = Open3.capture3(
      QUIET.merge("EVALUATION_PEAK" => report), *command, *arguments,
      chdir: directory
    )
    peak = Evaluation::Peak.of(report)
    Evaluation::Outcome.new("#{output}#{error}", status.exitstatus, peak, Evaluation::Outcome.parse(output))
  end

  def opting? = Open3.capture2e(*command, "--help").first.include?("checks: all")

  def command = ["ruby", "-r#{PEAK}", "-I#{@root}/lib", "#{@root}/exe/hashira"]
end
