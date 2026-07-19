# frozen_string_literal: true

module Hashira
  class CLI
    Options = Data.define(:directories, :mode, :baseline, :fail_on) do
      def self.parse(argv) = CommandLine.new(argv).options
    end
  end
end
