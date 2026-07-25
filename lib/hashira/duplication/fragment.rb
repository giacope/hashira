# frozen_string_literal: true

require "digest"

module Hashira
  module Duplication
    class Fragment
      DIGEST_LENGTH = 12

      def initialize(file, roots)
        @file = file
        @roots = roots
      end

      attr_reader :file

      def types = @types ||= nodes.map(&:type)

      def digest = Digest::SHA256.hexdigest(shape).slice(0, DIGEST_LENGTH)

      def shape = types.join(",")

      def mass = types.size

      def line = @roots.first.location.start_line

      def finish = @roots.last.location.end_line

      def location = "#{file}:#{line}"

      def range = "#{file}:#{line}-#{finish}"

      def sort_key = [file, line]

      def overlaps?(other) = file == other.file && line <= other.finish && other.line <= finish

      def overlaps_any?(others) = others.any? { overlaps?(it) }

      def nodes = @nodes ||= @roots.flat_map { Analysis::NodeWalk.collect(it) }
    end
  end
end
