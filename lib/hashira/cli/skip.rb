# frozen_string_literal: true

module Hashira
  class CLI
    module Skip
      module_function

      def parse(list)
        return [] unless list

        keys = list.split(",").map { key(it.strip) }
        raise Error, "cannot skip every analyzer" if (Pipeline::ANALYZERS - keys).empty?

        keys
      end

      def key(name)
        symbol = name.to_sym
        Pipeline::ANALYZERS.include?(symbol) ? symbol : unknown(name)
      end

      def unknown(name)
        raise Error, "unknown --skip #{name.inspect} (use: #{Pipeline::ANALYZERS.join(", ")})"
      end
    end
  end
end
