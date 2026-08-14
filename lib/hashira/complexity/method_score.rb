# frozen_string_literal: true

module Hashira
  module Complexity
    Increment = Data.define(:line, :cost, :label)

    MethodScore =
      Data.define(:subject, :file, :line, :cognitive, :calls, :increments) do
        def to_h = super.except(:increments)

        def cells = [subject, cognitive, calls, "#{file}:#{line}"]
      end

    ClassScore =
      Data.define(:name, :cognitive, :method_count, :peak) do
        def cells = [name, cognitive, method_count, peak]
      end
  end
end
