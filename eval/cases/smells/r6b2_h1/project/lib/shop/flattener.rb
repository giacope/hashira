# frozen_string_literal: true

require "fancy_diff"

module Shop
  class Flattener < ::FancyDiff::Flattener
    private

    def open_token = "("

    def close_token = ")"
  end

  class TupleFlattener < Flattener
    private

    def open_token = "["

    def close_token = "]"

    def stale = "|"
  end
end
