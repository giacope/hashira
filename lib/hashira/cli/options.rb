# frozen_string_literal: true

class Hashira::CLI
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
        Hashira::Pipeline.new(chosen, enabled: analyzers, packaging:, only:)
      end

      def analyzers = Hashira::Pipeline::ANALYZERS - skip
    end
end
