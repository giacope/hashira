# frozen_string_literal: true

module Hashira
  module Report
    History =
      Data.define(:depth) do
        def to_s
          commits = depth.commits
          shallow = depth.shallow
          return "no git history" unless shallow || commits.positive?
          "#{shallow ? "shallow" : "too little"} git history (#{Hashira::Report::Count.new(commits, "commit")})"
        end
      end
  end
end
