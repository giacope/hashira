# frozen_string_literal: true

module Hashira
  class CLI
    def self.run(argv)
      options = Options.parse(argv)
      usage?(options) ? Usage.public_send(options.mode) : new(options).run
    rescue Error => error
      report_failure(error)
    end

    def self.usage?(options) = %i[help version].include?(options.mode)

    def self.report_failure(error)
      warn "hashira: #{error.message}"
      1
    end

    def initialize(options)
      @options = options
      @pipeline = Pipeline.new(Project.detect(options.directories))
    end

    def run = Run.new(@pipeline, @options).exit_code
  end
end
