# frozen_string_literal: true

module Shop
  class Log
    class Default
      def initialize(color:) = @color = color

      def sent(message) = @color ? "\e[32m▶ #{message}\e[0m" : "▶ #{message}"

      def received(message) = @color ? "\e[33m◀ #{message}\e[0m" : "◀ #{message}"
    end
  end
end
