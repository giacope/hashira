# frozen_string_literal: true

module Hashira
  module CI
    class Improvement
      def initialize(label, io: $stdout)
        @label = label
        @io = io
      end

      def print(removed)
        return if removed.empty?

        @io.puts "#{@label} (improvement!): #{removed.join(", ")}"
        @io.puts "Lock it in: hashira --update-baseline"
      end
    end
  end
end
