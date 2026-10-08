# frozen_string_literal: true

require "prism"

module Hashira
  module Duplication
    RECURRING = 3

    Setting =
      Data.define(:declarative, :recurring) do
        def self.of(body)
          names = body.body.grep(Prism::CallNode).reject(&:receiver).map(&:name).tally
          new(declarative: true, recurring: names.select { |_, count| count >= RECURRING }.keys)
        end
      end

    Setting::CODE = Setting.new(declarative: false, recurring: [])
  end
end
