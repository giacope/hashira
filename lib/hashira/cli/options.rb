# frozen_string_literal: true

module Hashira::CLI
  Options =
    Data.define(
      :directories, :mode, :baseline, :fail_on, :skip, :only, :kinds, :packaging, :top, :compact, :strict, :home, :rules
    ) do
      def initialize(home: Hashira::CLI::Home.new([], "."), rules: Hashira::Config::Rules.new({}), strict: nil, **)
        super
      end

      def self.parse(argv) = Settings.new(argv).options

      def self.build(mode)
        new(
          directories: [], baseline: "", fail_on: [], skip: [], only: [], kinds: [],
          packaging: :auto, top: nil, compact: nil, mode:
        )
      end

      def pipeline
        chosen = project
        Hashira::Report::Notices.new.scanning(chosen.files.size, chosen.label)
        Hashira::Pipeline.new(chosen, enabled: analyzers, packaging:, only:).verify
      end

      def project(checks = Hashira::Checks.new)
        named = ruled.naming(kinds + fail_on).narrowed(kinds, checks)
        boundaries = Hashira::CI::Accepted.build(baseline).boundaries(rules.boundaries)
        Hashira::Project.new(directories, boundaries:, home: home.path, rules: named)
      end

      def analyzers(checks = Hashira::Checks.new) = checks.analyzers - skip
      private
      def ruled = strict ? rules.tightened : rules
    end
end
