# frozen_string_literal: true

module Shop
  class Log
    FORMATS = { default: Default, json: Json }.freeze

    def initialize(format, color)
      @formatter = FORMATS.fetch(format).new(color:)
      @lines = []
    end

    def sent(message) = @lines << @formatter.sent(message)

    def received(message) = @lines << @formatter.received(message)
  end
end
