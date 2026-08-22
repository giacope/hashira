# frozen_string_literal: true

module Hashira::CLI
  Options =
    Data.define(:directories, :mode, :baseline, :fail_on, :skip, :only, :packaging, :top, :compact) do
      def self.parse(argv) = CommandLine.new(argv).options

      def self.build(mode)
        new(
          directories: [], baseline: "", fail_on: [], skip: [], only: [],
          packaging: :auto, top: nil, compact: nil, mode:
        )
      end

      def pipeline
        chosen = Hashira::Project.new(directories)
        told = Hashira::Report::Notices.new
        told.scanning(chosen.files.size)
        told.rails if directories.empty? && File.exist?("config/application.rb")
        Hashira::Plan.new(enabled: analyzers, packaging:, only:, constraints: declared).pipeline(chosen)
      end

      def analyzers = Hashira::Plan::ANALYZERS - skip

      def declared
        reading = Hashira::Constraints::Reading.new(Hashira::Constraints::Reading::FILE)
        stop = reading.trouble
        raise(Hashira::Error, stop) if stop
        reading.declarations
      end
    end
end
