# frozen_string_literal: true

class Hashira::CLI
  PAGE = { directories: [], baseline: "", fail_on: [], skip: [], packaging: :auto, top: nil }.freeze

  Options =
    Data.define(:directories, :mode, :baseline, :fail_on, :skip, :packaging, :top) do
      def self.parse(argv) = CommandLine.new(argv).options

      def self.page(mode) = new(**PAGE, mode:)

      def initialize(**attributes)
        super
        FailOn.armed(fail_on, skip)
      end

      def pipeline
        Hashira::Pipeline.new(Hashira::Project.detect(directories), enabled: analyzers, packaging:)
      end

      def analyzers = Hashira::Pipeline::ANALYZERS - skip
    end
end
