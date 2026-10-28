# frozen_string_literal: true

require "json"

module Shop
  class Log
    class Json
      def initialize(color:) = @color = color

      def sent(message) = JSON.generate(direction: "sent", message:)

      def received(message) = JSON.generate(direction: "received", message:)

      def pretty(message) = JSON.pretty_generate(message)
    end
  end
end
