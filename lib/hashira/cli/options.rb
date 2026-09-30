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
        Hashira::Report::Notices.new.scanning(chosen.files.size, chosen.label)
        Hashira::Pipeline.new(chosen, enabled: analyzers, packaging:, only:).verify
      end

      def analyzers = Hashira::Pipeline::ANALYZERS - skip
      private
      def decisions
        recorded = Hashira::CI::Baseline.new(baseline)
        raise(Hashira::Error, recorded.trouble) if recorded.trouble
        recorded
      end
    end
end
