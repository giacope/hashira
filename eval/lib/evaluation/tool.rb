# frozen_string_literal: true

class Evaluation::Tool
  PEAK = File.join(Evaluation::ROOT, "probe", "peak.rb")

  QUIET = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT RUBYLIB].to_h { [it, nil] }.freeze

  def self.build(root) = new(File.expand_path(root))

  def initialize(root)
    @root = root
  end

  def call(directory, arguments)
    Dir.mktmpdir("peak") { |scratch| run(directory, arguments, File.join(scratch, "peak")) }
  end

  def commit = Open3.capture2e("git", "-C", @root, "rev-parse", "--short", "HEAD").first.strip

  private

  def run(directory, arguments, report)
    output, error, status = Open3.capture3(
      QUIET.merge("EVALUATION_PEAK" => report), *command, *arguments,
      chdir: directory
    )
    peak = Evaluation::Peak.of(report)
    Evaluation::Outcome.new(status: status.exitstatus, output:, error:, peak:, json: Evaluation::Outcome.parse(output))
  end

  def command = ["ruby", "-r#{PEAK}", "-I#{@root}/lib", "#{@root}/exe/hashira"]
end
