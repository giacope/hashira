# frozen_string_literal: true

module Hashira::CLI
  BLANK = %i[arg field parse mode].to_h { [it, nil] }.freeze

  Flag =
    Data.define(:name, :arg, :default, :field, :parse, :mode, :text, :page) do
      def initialize(**attributes) = super(**BLANK, default: "", page: false, **attributes)

      def read(arguments) = arg ? take(arguments) : arguments.drop(name)

      def take(arguments)
        raw = arguments.take(name, default)
        parse ? parse.parse(raw) : raw
      end

      def bid(value)
        case [mode, value]
        in [nil, _] | [_, nil] | [_, []] then nil
        in [:parsed, chosen] then ["#{name} #{chosen}", chosen]
        else [name, mode]
        end
      end

      def label = [name, arg].compact.join(" ")

      def names = name.split(", ")
    end
end
