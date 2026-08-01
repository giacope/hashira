# frozen_string_literal: true

class Hashira::CLI
  def self.run(argv)
    options = Options.parse(argv)
    usage?(options) ? Usage.public_send(options.mode) : new(options).run
  rescue Hashira::Error => error
    failure(error)
  end

  def self.usage?(options) = %i[help version].include?(options.mode)

  def self.failure(error)
    warn("hashira: #{error.message}")
    1
  end

  def initialize(options)
    @options = options
    @pipeline = options.pipeline
  end

  def run = Run.new(@pipeline, @options).status
end
