# frozen_string_literal: true

class Hashira::CLI
  Options =
    Data.define(:directories, :mode, :baseline, :fail_on, :skip, :packaging) do
      def self.parse(argv) = CommandLine.new(argv).options

      def self.page(mode) = new(directories: [], mode:, baseline: "", fail_on: [], skip: [], packaging: :auto)

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
