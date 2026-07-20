# frozen_string_literal: true

module Hashira
  class CLI
    module FailOn
      KINDS = {
        "cycles" => "cycle", "cycle" => "cycle",
        "sdp" => "sdp_violation", "sdp_violation" => "sdp_violation"
      }.freeze

      module_function

      def parse(list)
        return [] unless list

        list.split(",").map { kind(it.strip) }.uniq
      end

      def kind(name)
        KINDS.fetch(name) do
          raise Error, "unknown --fail-on kind #{name.inspect} (use: #{KINDS.keys.join(", ")})"
        end
      end
    end
  end
end
