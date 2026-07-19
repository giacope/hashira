# frozen_string_literal: true

module Hashira
  module Analysis
    module RootNamespace
      module_function

      def infer(definitions)
        definitions.map { |_node, full, _package| full.first }
                   .tally.max_by { |_name, count| count }&.first
      end
    end
  end
end
