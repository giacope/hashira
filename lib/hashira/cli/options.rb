# frozen_string_literal: true

module Hashira::CLI
  Options =
    Data.define(:directories, :mode, :baseline, :fail_on, :skip, :only, :kinds, :packaging, :top, :compact) do
      def self.parse(argv) = CommandLine.new(argv).options

      def self.build(mode)
        new(
          directories: [], baseline: "", fail_on: [], skip: [], only: [], kinds: [],
          packaging: :auto, top: nil, compact: nil, mode:
        )
      end

      def pipeline
        chosen = Hashira::Project.new(directories, boundaries: decisions.boundaries)
        announce(chosen)
        Hashira::Pipeline.new(chosen, enabled: analyzers, packaging:, only:).verify
      end

      def analyzers = Hashira::Pipeline::ANALYZERS - skip
      private
      def decisions
        recorded = Hashira::CI::Baseline.new(baseline)
        raise(Hashira::Error, recorded.trouble) if recorded.trouble
        recorded
      end

      def announce(project)
        told = Hashira::Report::Notices.new
        told.scanning(project.files.size)
        told.rails if directories.empty? && File.exist?("config/application.rb")
      end
    end
end
