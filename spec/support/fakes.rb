# frozen_string_literal: true

module Fakes
  Score =
    Data.define(:file, :cognitive) do
      def charge = [file, cognitive]
    end

  Complexity = Data.define(:ranked)

  Duplication = Data.define(:coverage)

  Detail =
    Data.define(:fields) do
      def to_h = fields

      def phrase(package) = "#{package} (#{fields[:site]})"
    end

  Mark = Data.define(:magnitude, :trace)

  class Directive
    def initialize
      @asked = []
    end

    def covers?(_kind, anchor)
      @asked << anchor
      false
    end

    def to_a = @asked
  end

  Hosting =
    Data.define(:hosted) do
      def hosted?(path) = hosted.include?(path)

      def patched?(_path) = false

      def backed?(_path) = false
    end

  Hotspots =
    Data.define(:files, :weighed) do
      def weighed? = weighed
    end
end
