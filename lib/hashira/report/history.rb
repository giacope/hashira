# frozen_string_literal: true

module Hashira
  module Report
    class History
      def initialize(depth)
        @depth = depth
      end

      def to_s
        commits = depth.commits
        shallow = depth.shallow
        return "no git history" unless shallow || commits.positive?
        "#{shallow ? "shallow" : "too little"} git history (#{Hashira::Prose::Count.new(commits, "commit")})"
      end

      private

      attr_reader :depth
    end
  end
end
