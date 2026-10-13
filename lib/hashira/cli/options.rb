# frozen_string_literal: true

module Hashira::CLI
  BASELINE = "hashira_baseline.json"

  Options =
    Data.define(
      :directories, :mode, :baseline, :fail_on, :skip, :only, :kinds, :packaging, :top, :compact, :home, :rules
    ) do
      def initialize(home: Hashira::CLI::Home::HERE, rules: Hashira::Config::Rules::NONE, **) = super

      def self.parse(argv) = Settings.new(argv).options

      def self.build(mode)
        new(
          directories: [], baseline: "", fail_on: [], skip: [], only: [], kinds: [],
          packaging: :auto, top: nil, compact: nil, mode:
        )
      end

      def pipeline
        named = rules.naming(kinds + fail_on)
        chosen = Hashira::Project.new(directories, boundaries: decisions.boundaries, home: home.path, rules: named)
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
